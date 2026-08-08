package com.example.flutter_braintree;

import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Bundle;
import android.text.TextUtils;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import java.io.Serializable;
import java.util.HashMap;
import java.util.Locale;

import com.braintreepayments.api.card.Card;
import com.braintreepayments.api.card.CardClient;
import com.braintreepayments.api.card.CardNonce;
import com.braintreepayments.api.card.CardResult;
import com.braintreepayments.api.card.CardTokenizeCallback;
import com.braintreepayments.api.datacollector.DataCollector;
import com.braintreepayments.api.datacollector.DataCollectorCallback;
import com.braintreepayments.api.datacollector.DataCollectorRequest;
import com.braintreepayments.api.datacollector.DataCollectorResult;
import com.braintreepayments.api.paypal.PayPalAccountNonce;
import com.braintreepayments.api.paypal.PayPalCheckoutRequest;
import com.braintreepayments.api.paypal.PayPalClient;
import com.braintreepayments.api.paypal.PayPalLauncher;
import com.braintreepayments.api.paypal.PayPalPaymentAuthRequest;
import com.braintreepayments.api.paypal.PayPalPaymentAuthResult;
import com.braintreepayments.api.paypal.PayPalPaymentIntent;
import com.braintreepayments.api.paypal.PayPalPaymentUserAction;
import com.braintreepayments.api.paypal.PayPalPendingRequest;
import com.braintreepayments.api.paypal.PayPalRequest;
import com.braintreepayments.api.paypal.PayPalResult;
import com.braintreepayments.api.paypal.PayPalVaultRequest;
import com.braintreepayments.api.threedsecure.ThreeDSecureClient;
import com.braintreepayments.api.threedsecure.ThreeDSecureLauncher;
import com.braintreepayments.api.threedsecure.ThreeDSecureNonce;
import com.braintreepayments.api.threedsecure.ThreeDSecurePaymentAuthRequest;
import com.braintreepayments.api.threedsecure.ThreeDSecurePaymentAuthRequestCallback;
import com.braintreepayments.api.threedsecure.ThreeDSecurePaymentAuthResult;
import com.braintreepayments.api.threedsecure.ThreeDSecurePostalAddress;
import com.braintreepayments.api.threedsecure.ThreeDSecureRequest;
import com.braintreepayments.api.threedsecure.ThreeDSecureResult;

/**
 * Hosts the Braintree Android v5 flows that require a {@code ComponentActivity}
 * with launchers registered before the activity reaches the CREATED state:
 * credit card tokenization with 3D Secure, and PayPal.
 *
 * The plain (non-3DS) card path is handled inline in {@link FlutterBraintreePlugin}.
 */
public class FlutterBraintreeCustom extends AppCompatActivity {
    private static final String PREFS = "flutter_braintree";
    private static final String KEY_PAYPAL_PENDING = "paypal_pending_request";

    private String authorization;
    private String type;
    private String amount;
    private boolean collectDeviceData;

    private PayPalClient payPalClient;
    private PayPalLauncher payPalLauncher;
    private ThreeDSecureClient threeDSecureClient;
    private ThreeDSecureLauncher threeDSecureLauncher;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        Intent intent = getIntent();
        authorization = intent.getStringExtra("authorization");
        type = intent.getStringExtra("type");
        amount = intent.getStringExtra("amount");
        collectDeviceData = intent.getBooleanExtra("collectDeviceData", false);

        if (authorization == null || type == null) {
            returnError("Authorization and request type are required.");
            return;
        }

        // Launchers must be created before the activity is RESUMED.
        threeDSecureLauncher = new ThreeDSecureLauncher(this, paymentAuthResult ->
                threeDSecureClient.tokenize(paymentAuthResult, threeDSecureResult -> {
                    if (threeDSecureResult instanceof ThreeDSecureResult.Success) {
                        finishWithNonce(buildThreeDSecureNonceMap(
                                ((ThreeDSecureResult.Success) threeDSecureResult).getNonce()));
                    } else if (threeDSecureResult instanceof ThreeDSecureResult.Failure) {
                        returnError(((ThreeDSecureResult.Failure) threeDSecureResult).getError());
                    } else {
                        returnCanceled();
                    }
                }));
        payPalLauncher = new PayPalLauncher();

        if (savedInstanceState == null) {
            if ("tokenizeCreditCard".equals(type)) {
                startCardFlow();
            } else if ("requestPaypalNonce".equals(type)) {
                startPayPalFlow();
            } else {
                returnError("Invalid request type: " + type);
            }
        }
    }

    @Override
    protected void onNewIntent(Intent newIntent) {
        super.onNewIntent(newIntent);
        setIntent(newIntent);
    }

    @Override
    protected void onResume() {
        super.onResume();
        handlePayPalReturn();
    }

    // MARK: - Credit card + 3D Secure

    private void startCardFlow() {
        Intent intent = getIntent();
        Card card = new Card();
        card.setNumber(intent.getStringExtra("cardNumber"));
        card.setExpirationMonth(intent.getStringExtra("expirationMonth"));
        card.setExpirationYear(intent.getStringExtra("expirationYear"));
        card.setCvv(intent.getStringExtra("cvv"));
        card.setCardholderName(intent.getStringExtra("cardholderName"));

        CardClient cardClient = new CardClient(this, authorization);
        cardClient.tokenize(card, new CardTokenizeCallback() {
            @Override
            public void onCardResult(CardResult cardResult) {
                if (cardResult instanceof CardResult.Success) {
                    startThreeDSecure(((CardResult.Success) cardResult).getNonce());
                } else if (cardResult instanceof CardResult.Failure) {
                    returnError(((CardResult.Failure) cardResult).getError());
                }
            }
        });
    }

    private void startThreeDSecure(CardNonce cardNonce) {
        Intent intent = getIntent();

        ThreeDSecureRequest request = new ThreeDSecureRequest();
        request.setNonce(cardNonce.getString());
        request.setAmount(amount);
        String email = intent.getStringExtra("email");
        if (email != null) {
            request.setEmail(email);
        }
        request.setBillingAddress(buildBillingAddress(intent));

        threeDSecureClient = new ThreeDSecureClient(this, authorization);
        threeDSecureClient.createPaymentAuthRequest(this, request, new ThreeDSecurePaymentAuthRequestCallback() {
            @Override
            public void onThreeDSecurePaymentAuthRequest(ThreeDSecurePaymentAuthRequest paymentAuthRequest) {
                if (paymentAuthRequest instanceof ThreeDSecurePaymentAuthRequest.ReadyToLaunch) {
                    threeDSecureLauncher.launch((ThreeDSecurePaymentAuthRequest.ReadyToLaunch) paymentAuthRequest);
                } else if (paymentAuthRequest instanceof ThreeDSecurePaymentAuthRequest.LaunchNotRequired) {
                    // No challenge required; the verified nonce is already available.
                    finishWithNonce(buildThreeDSecureNonceMap(
                            ((ThreeDSecurePaymentAuthRequest.LaunchNotRequired) paymentAuthRequest).getNonce()));
                } else if (paymentAuthRequest instanceof ThreeDSecurePaymentAuthRequest.Failure) {
                    returnError(((ThreeDSecurePaymentAuthRequest.Failure) paymentAuthRequest).getError());
                }
            }
        });
    }

    @Nullable
    private ThreeDSecurePostalAddress buildBillingAddress(Intent intent) {
        String givenName = intent.getStringExtra("billing_givenName");
        String surname = intent.getStringExtra("billing_surname");
        String streetAddress = intent.getStringExtra("billing_streetAddress");
        String extendedAddress = intent.getStringExtra("billing_extendedAddress");
        String locality = intent.getStringExtra("billing_locality");
        String region = intent.getStringExtra("billing_region");
        String postalCode = intent.getStringExtra("billing_postalCode");
        String countryCode = intent.getStringExtra("billing_countryCodeAlpha2");
        String phoneNumber = intent.getStringExtra("billing_phoneNumber");

        if (givenName == null && surname == null && streetAddress == null && postalCode == null) {
            return null;
        }
        // ThreeDSecurePostalAddress has no @JvmOverloads, so use the full
        // positional constructor: (givenName, surname, streetAddress,
        // extendedAddress, line3, locality, region, postalCode,
        // countryCodeAlpha2, phoneNumber).
        return new ThreeDSecurePostalAddress(
                givenName, surname, streetAddress, extendedAddress, null,
                locality, region, postalCode, countryCode, phoneNumber);
    }

    // MARK: - PayPal

    private void startPayPalFlow() {
        try {
            Intent intent = getIntent();
            String appLinkReturnUrl = intent.getStringExtra("appLinkReturnUrl");

            // Braintree v5 returns from the PayPal web flow either via a verified
            // Android App Link (production) or, when that is unavailable/unverified,
            // via a custom deep-link scheme fallback. We always supply the
            // fallback scheme (derived from the package, e.g.
            // "com.example.app.braintree") so PayPal works in sandbox without a
            // registered App Link domain. The matching <intent-filter> must be
            // declared on this activity (see the example AndroidManifest.xml).
            String fallbackScheme = deepLinkFallbackScheme();

            // The PayPalClient constructor requires a non-null App Link Uri. When
            // the merchant hasn't configured one, reuse the deep-link scheme as a
            // placeholder Uri; it won't verify, so the SDK uses the scheme.
            Uri appLinkUri = TextUtils.isEmpty(appLinkReturnUrl)
                    ? Uri.parse(fallbackScheme + "://braintree")
                    : Uri.parse(appLinkReturnUrl);

            payPalClient = new PayPalClient(this, authorization, appLinkUri, fallbackScheme);

            PayPalRequest request = buildPayPalRequest(intent);
            payPalClient.createPaymentAuthRequest(this, request, paymentAuthRequest -> {
                try {
                    if (paymentAuthRequest instanceof PayPalPaymentAuthRequest.ReadyToLaunch) {
                        PayPalPendingRequest pendingRequest = payPalLauncher.launch(
                                this, (PayPalPaymentAuthRequest.ReadyToLaunch) paymentAuthRequest);
                        if (pendingRequest instanceof PayPalPendingRequest.Started) {
                            storePayPalPendingRequest(((PayPalPendingRequest.Started) pendingRequest).getPendingRequestString());
                        } else if (pendingRequest instanceof PayPalPendingRequest.Failure) {
                            returnError(((PayPalPendingRequest.Failure) pendingRequest).getError());
                        }
                    } else if (paymentAuthRequest instanceof PayPalPaymentAuthRequest.Failure) {
                        returnError(((PayPalPaymentAuthRequest.Failure) paymentAuthRequest).getError());
                    }
                } catch (Exception e) {
                    returnError(e);
                }
            });
        } catch (Exception e) {
            returnError(e);
        }
    }

    /** Custom deep-link scheme used as the PayPal browser-switch fallback. */
    private String deepLinkFallbackScheme() {
        // URL schemes must be lowercase and cannot contain underscores.
        return getPackageName().replace("_", "").toLowerCase(Locale.ROOT) + ".braintree";
    }

    private PayPalRequest buildPayPalRequest(Intent intent) {
        String currencyCode = intent.getStringExtra("currencyCode");
        String displayName = intent.getStringExtra("displayName");
        String billingAgreementDescription = intent.getStringExtra("billingAgreementDescription");

        if (TextUtils.isEmpty(amount)) {
            // Vault (billing agreement) flow.
            PayPalVaultRequest vaultRequest = new PayPalVaultRequest(false);
            vaultRequest.setDisplayName(displayName);
            vaultRequest.setBillingAgreementDescription(billingAgreementDescription);
            return vaultRequest;
        }

        // One-time checkout flow.
        PayPalCheckoutRequest checkoutRequest = new PayPalCheckoutRequest(amount, false);
        checkoutRequest.setCurrencyCode(currencyCode);
        checkoutRequest.setDisplayName(displayName);
        checkoutRequest.setIntent(mapPayPalIntent(intent.getStringExtra("payPalPaymentIntent")));
        checkoutRequest.setUserAction(mapPayPalUserAction(intent.getStringExtra("payPalPaymentUserAction")));
        return checkoutRequest;
    }

    private PayPalPaymentIntent mapPayPalIntent(@Nullable String value) {
        if ("order".equals(value)) return PayPalPaymentIntent.ORDER;
        if ("sale".equals(value)) return PayPalPaymentIntent.SALE;
        return PayPalPaymentIntent.AUTHORIZE;
    }

    private PayPalPaymentUserAction mapPayPalUserAction(@Nullable String value) {
        if ("commit".equals(value)) return PayPalPaymentUserAction.USER_ACTION_COMMIT;
        return PayPalPaymentUserAction.USER_ACTION_DEFAULT;
    }

    private void handlePayPalReturn() {
        if (payPalClient == null || payPalLauncher == null) return;
        String pending = getPayPalPendingRequest();
        if (pending == null) return;

        try {
            PayPalPaymentAuthResult authResult = payPalLauncher.handleReturnToApp(
                    new PayPalPendingRequest.Started(pending), getIntent());

            if (authResult instanceof PayPalPaymentAuthResult.Success) {
                clearPayPalPendingRequest();
                payPalClient.tokenize((PayPalPaymentAuthResult.Success) authResult, payPalResult -> {
                    if (payPalResult instanceof PayPalResult.Success) {
                        finishWithNonce(buildPayPalNonceMap(((PayPalResult.Success) payPalResult).getNonce()));
                    } else if (payPalResult instanceof PayPalResult.Failure) {
                        returnError(((PayPalResult.Failure) payPalResult).getError());
                    } else {
                        returnCanceled();
                    }
                });
            } else if (authResult instanceof PayPalPaymentAuthResult.Failure) {
                clearPayPalPendingRequest();
                returnError(((PayPalPaymentAuthResult.Failure) authResult).getError());
            }
            // PayPalPaymentAuthResult.NoResult: no browser-switch result in this
            // intent yet; keep waiting for the return.
        } catch (Exception e) {
            clearPayPalPendingRequest();
            returnError(e);
        }
    }

    private void storePayPalPendingRequest(String value) {
        getSharedPreferences(PREFS, MODE_PRIVATE).edit().putString(KEY_PAYPAL_PENDING, value).apply();
    }

    @Nullable
    private String getPayPalPendingRequest() {
        return getSharedPreferences(PREFS, MODE_PRIVATE).getString(KEY_PAYPAL_PENDING, null);
    }

    private void clearPayPalPendingRequest() {
        getSharedPreferences(PREFS, MODE_PRIVATE).edit().remove(KEY_PAYPAL_PENDING).apply();
    }

    // MARK: - Nonce mapping

    private HashMap<String, Object> buildThreeDSecureNonceMap(ThreeDSecureNonce nonce) {
        HashMap<String, Object> map = new HashMap<>();
        map.put("nonce", nonce.getString());
        map.put("typeLabel", nonce.getCardType());
        map.put("description", "ending in ••" + nonce.getLastTwo());
        map.put("isDefault", nonce.isDefault());
        if (amount != null) {
            map.put("amount", amount);
        }
        return map;
    }

    private HashMap<String, Object> buildPayPalNonceMap(PayPalAccountNonce nonce) {
        HashMap<String, Object> map = new HashMap<>();
        map.put("nonce", nonce.getString());
        map.put("isDefault", nonce.isDefault());
        map.put("typeLabel", "PayPal");
        map.put("description", nonce.getEmail());
        map.put("paypalPayerId", nonce.getPayerId());
        if (amount != null) {
            map.put("amount", amount);
        }
        return map;
    }

    // MARK: - Result handling

    /**
     * Optionally collects device data before returning the nonce to the plugin.
     */
    private void finishWithNonce(HashMap<String, Object> nonceMap) {
        if (!collectDeviceData) {
            returnSuccess(nonceMap);
            return;
        }
        DataCollector dataCollector = new DataCollector(this, authorization);
        dataCollector.collectDeviceData(this, new DataCollectorRequest(false), new DataCollectorCallback() {
            @Override
            public void onDataCollectorResult(DataCollectorResult dataCollectorResult) {
                if (dataCollectorResult instanceof DataCollectorResult.Success) {
                    nonceMap.put("deviceData", ((DataCollectorResult.Success) dataCollectorResult).getDeviceData());
                }
                returnSuccess(nonceMap);
            }
        });
    }

    private void returnSuccess(HashMap<String, Object> nonceMap) {
        Intent result = new Intent();
        result.putExtra("nonce", (Serializable) nonceMap);
        setResult(RESULT_OK, result);
        finish();
    }

    private void returnError(Exception error) {
        returnError(error != null ? error.getMessage() : "Unknown Braintree error.");
    }

    private void returnError(String message) {
        Intent result = new Intent();
        result.putExtra("error", message);
        setResult(RESULT_CANCELED, result);
        finish();
    }

    private void returnCanceled() {
        setResult(RESULT_CANCELED);
        finish();
    }
}
