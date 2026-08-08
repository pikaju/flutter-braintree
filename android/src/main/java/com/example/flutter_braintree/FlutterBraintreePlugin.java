package com.example.flutter_braintree;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;

import androidx.annotation.Nullable;

import java.io.Serializable;
import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener;

import com.braintreepayments.api.card.Card;
import com.braintreepayments.api.card.CardClient;
import com.braintreepayments.api.card.CardNonce;
import com.braintreepayments.api.card.CardResult;
import com.braintreepayments.api.card.CardTokenizeCallback;
import com.braintreepayments.api.datacollector.DataCollector;
import com.braintreepayments.api.datacollector.DataCollectorCallback;
import com.braintreepayments.api.datacollector.DataCollectorRequest;
import com.braintreepayments.api.datacollector.DataCollectorResult;

/**
 * Implements the {@code flutter_braintree.custom} method channel against the
 * direct Braintree Android v5 SDK (the deprecated Drop-in library has been
 * removed). Card tokenization without 3D Secure runs inline here; 3D Secure and
 * PayPal require a {@link androidx.activity.ComponentActivity} with registered
 * launchers, so they are delegated to {@link FlutterBraintreeCustom}.
 */
public class FlutterBraintreePlugin implements FlutterPlugin, ActivityAware, MethodCallHandler, ActivityResultListener {
    private static final int CUSTOM_ACTIVITY_REQUEST_CODE = 0x420;

    private Context applicationContext;
    private Activity activity;
    private Result activeResult;
    private MethodChannel channel;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        applicationContext = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "flutter_braintree.custom");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        applicationContext = null;
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
    }

    @Override
    public void onAttachedToActivity(ActivityPluginBinding binding) {
        activity = binding.getActivity();
        binding.addActivityResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activity = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
        activity = binding.getActivity();
        binding.addActivityResultListener(this);
    }

    @Override
    public void onDetachedFromActivity() {
        activity = null;
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        if (activeResult != null) {
            result.error("already_running", "Cannot launch another Braintree activity while one is already running.", null);
            return;
        }

        String authorization = call.argument("authorization");
        if (authorization == null) {
            result.error("authorization_missing", "Authorization (client token or tokenization key) is required.", null);
            return;
        }

        try {
            switch (call.method) {
                case "tokenizeCreditCard":
                    handleTokenizeCreditCard(authorization, call, result);
                    break;
                case "requestPaypalNonce":
                    handlePayPal(authorization, call, result);
                    break;
                case "requestApplePayNonce":
                    result.error("not_available", "Apple Pay is only available on iOS.", null);
                    break;
                default:
                    result.notImplemented();
                    break;
            }
        } catch (Exception e) {
            // Never let a native exception crash the host app; surface it as a
            // catchable PlatformException instead.
            if (activeResult != null) {
                returnError(e);
            } else {
                result.error("braintree_error", e.getMessage(), null);
            }
        }
    }

    // MARK: - Credit card

    private void handleTokenizeCreditCard(String authorization, MethodCall call, Result result) {
        Map<String, Object> request = call.argument("request");
        if (request == null) {
            result.success(null);
            return;
        }

        boolean requires3DS = Boolean.TRUE.equals(call.argument("requestThreeDSecureVerification"));
        boolean collectDeviceData = Boolean.TRUE.equals(call.argument("collectDeviceData"));
        final String amount = (String) request.get("amount");

        // 3D Secure needs a ComponentActivity with a registered launcher, so it
        // is delegated to FlutterBraintreeCustom. The common non-3DS path runs
        // inline against CardClient.
        if (requires3DS) {
            Intent intent = new Intent(activity, FlutterBraintreeCustom.class);
            intent.putExtra("type", "tokenizeCreditCard");
            intent.putExtra("authorization", authorization);
            intent.putExtra("collectDeviceData", collectDeviceData);
            intent.putExtra("requestThreeDSecureVerification", true);
            intent.putExtra("cardNumber", (String) request.get("cardNumber"));
            intent.putExtra("expirationMonth", (String) request.get("expirationMonth"));
            intent.putExtra("expirationYear", (String) request.get("expirationYear"));
            intent.putExtra("cvv", (String) request.get("cvv"));
            intent.putExtra("cardholderName", (String) request.get("cardholderName"));
            intent.putExtra("amount", amount);
            intent.putExtra("email", (String) call.argument("email"));
            putBillingAddressExtras(intent, call);
            launchCustomActivity(intent, result);
            return;
        }

        Card card = new Card();
        card.setNumber((String) request.get("cardNumber"));
        card.setExpirationMonth((String) request.get("expirationMonth"));
        card.setExpirationYear((String) request.get("expirationYear"));
        card.setCvv((String) request.get("cvv"));
        card.setCardholderName((String) request.get("cardholderName"));

        activeResult = result;
        CardClient cardClient = new CardClient(applicationContext, authorization);
        cardClient.tokenize(card, new CardTokenizeCallback() {
            @Override
            public void onCardResult(CardResult cardResult) {
                if (cardResult instanceof CardResult.Success) {
                    CardNonce nonce = ((CardResult.Success) cardResult).getNonce();
                    HashMap<String, Object> nonceMap = new HashMap<>();
                    nonceMap.put("nonce", nonce.getString());
                    nonceMap.put("typeLabel", nonce.getCardType());
                    nonceMap.put("description", "ending in ••" + nonce.getLastTwo());
                    nonceMap.put("isDefault", nonce.isDefault());
                    if (amount != null) {
                        nonceMap.put("amount", amount);
                    }
                    finishInlineWithNonce(authorization, nonceMap, collectDeviceData);
                } else if (cardResult instanceof CardResult.Failure) {
                    returnError(((CardResult.Failure) cardResult).getError());
                }
            }
        });
    }

    /**
     * Optionally collects device data before returning the tokenized nonce, then
     * resolves the pending Flutter result.
     */
    private void finishInlineWithNonce(String authorization, HashMap<String, Object> nonceMap, boolean collectDeviceData) {
        if (!collectDeviceData) {
            returnSuccess(nonceMap);
            return;
        }
        DataCollector dataCollector = new DataCollector(applicationContext, authorization);
        dataCollector.collectDeviceData(applicationContext, new DataCollectorRequest(false), new DataCollectorCallback() {
            @Override
            public void onDataCollectorResult(DataCollectorResult dataCollectorResult) {
                if (dataCollectorResult instanceof DataCollectorResult.Success) {
                    nonceMap.put("deviceData", ((DataCollectorResult.Success) dataCollectorResult).getDeviceData());
                }
                returnSuccess(nonceMap);
            }
        });
    }

    // MARK: - PayPal (delegated to the launcher activity)

    private void handlePayPal(String authorization, MethodCall call, Result result) {
        Map<String, Object> request = call.argument("request");
        if (request == null) {
            result.success(null);
            return;
        }

        Intent intent = new Intent(activity, FlutterBraintreeCustom.class);
        intent.putExtra("type", "requestPaypalNonce");
        intent.putExtra("authorization", authorization);
        intent.putExtra("collectDeviceData", Boolean.TRUE.equals(call.argument("collectDeviceData")));
        intent.putExtra("amount", (String) request.get("amount"));
        intent.putExtra("currencyCode", (String) request.get("currencyCode"));
        intent.putExtra("displayName", (String) request.get("displayName"));
        intent.putExtra("billingAgreementDescription", (String) request.get("billingAgreementDescription"));
        intent.putExtra("payPalPaymentIntent", (String) request.get("payPalPaymentIntent"));
        intent.putExtra("payPalPaymentUserAction", (String) request.get("payPalPaymentUserAction"));
        intent.putExtra("appLinkReturnUrl", (String) request.get("appLinkReturnUrl"));
        launchCustomActivity(intent, result);
    }

    // MARK: - Helpers

    @SuppressWarnings("unchecked")
    private void putBillingAddressExtras(Intent intent, MethodCall call) {
        Map<String, Object> billing = call.argument("billingAddress");
        if (billing == null) return;
        String[] keys = {"givenName", "surname", "phoneNumber", "streetAddress",
                "extendedAddress", "locality", "region", "postalCode", "countryCodeAlpha2"};
        for (String key : keys) {
            intent.putExtra("billing_" + key, (String) billing.get(key));
        }
    }

    private void launchCustomActivity(Intent intent, Result result) {
        if (activity == null) {
            result.error("no_activity", "Plugin is not attached to an Activity.", null);
            return;
        }
        activeResult = result;
        activity.startActivityForResult(intent, CUSTOM_ACTIVITY_REQUEST_CODE);
    }

    private void returnSuccess(Object value) {
        if (activeResult == null) return;
        activeResult.success(value);
        activeResult = null;
    }

    private void returnError(Exception error) {
        if (activeResult == null) return;
        activeResult.error("braintree_error", error != null ? error.getMessage() : "Unknown Braintree error.", null);
        activeResult = null;
    }

    @Override
    @SuppressWarnings("unchecked")
    public boolean onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        if (activeResult == null || requestCode != CUSTOM_ACTIVITY_REQUEST_CODE) {
            return false;
        }

        if (resultCode == Activity.RESULT_OK && data != null) {
            Map<String, Object> nonceMap = (Map<String, Object>) data.getSerializableExtra("nonce");
            activeResult.success(nonceMap);
        } else if (data != null && data.getStringExtra("error") != null) {
            activeResult.error("braintree_error", data.getStringExtra("error"), null);
        } else {
            // User canceled or no result.
            activeResult.success(null);
        }
        activeResult = null;
        return true;
    }
}
