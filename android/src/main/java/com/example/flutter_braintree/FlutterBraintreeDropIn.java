package com.example.flutter_braintree;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener;
import io.flutter.plugin.common.PluginRegistry.Registrar;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;

import com.braintreepayments.api.dropin.DropInActivity;
import com.braintreepayments.api.dropin.DropInRequest;
import com.braintreepayments.api.dropin.DropInResult;
import com.braintreepayments.api.models.GooglePaymentRequest;
import com.braintreepayments.api.models.PayPalRequest;
import com.braintreepayments.api.models.PaymentMethodNonce;

import com.google.android.gms.wallet.TransactionInfo;
import com.google.android.gms.wallet.WalletConstants;

import java.util.HashMap;

public class FlutterBraintreeDropIn implements FlutterPlugin, ActivityAware, MethodCallHandler, ActivityResultListener {
  private static final int DROP_IN_REQUEST_CODE = 0x1337;

  private Activity activity;
  private Result activeResult;

  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), "flutter_braintree.drop_in");
    FlutterBraintreeDropIn dropIn = new FlutterBraintreeDropIn();
    dropIn.activity = registrar.activity();
    registrar.addActivityResultListener(dropIn);
    channel.setMethodCallHandler(dropIn);
  }

  @Override
  public void onAttachedToEngine(FlutterPluginBinding binding) {
    final MethodChannel channel = new MethodChannel(binding.getBinaryMessenger(), "flutter_braintree.drop_in");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onDetachedFromEngine(FlutterPluginBinding binding) {

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
    if (call.method.equals("start")) {
      String clientToken = call.argument("clientToken");
      String tokenizationKey = call.argument("tokenizationKey");
      DropInRequest dropInRequest = new DropInRequest()
              .amount((String) call.argument("amount"))
              .collectDeviceData((Boolean) call.argument("collectDeviceData"))
              .requestThreeDSecureVerification((Boolean) call.argument("requestThreeDSecureVerification"))
              .maskCardNumber((Boolean) call.argument("maskCardNumber"))
              .vaultManager((Boolean) call.argument("vaultManagerEnabled"));


      if (clientToken != null)
        dropInRequest.clientToken(clientToken);
      else if (tokenizationKey != null)
        dropInRequest.tokenizationKey(tokenizationKey);

      readGooglePaymentParameters(dropInRequest, call);
      readPayPalParameters(dropInRequest, call);
      if (!((Boolean) call.argument("venmoEnabled")))
        dropInRequest.disableVenmo();
      if (!((Boolean) call.argument("cardEnabled")))
        dropInRequest.disableCard();
      if (!((Boolean) call.argument("paypalEnabled")))
        dropInRequest.disablePayPal();

      if (activeResult != null) {
        result.error("drop_in_already_running", "Cannot launch another Drop-in activity while one is already running.", null);
        return;
      }
      this.activeResult = result;
      activity.startActivityForResult(dropInRequest.getIntent(activity), DROP_IN_REQUEST_CODE);
    } else {
      result.notImplemented();
    }
  }

  private static void readGooglePaymentParameters(DropInRequest dropInRequest, MethodCall call) {
    HashMap<String, Object> arg = call.argument("googlePaymentRequest");
    if (arg == null) {
      dropInRequest.disableGooglePayment();
      return;
    }
    GooglePaymentRequest googlePaymentRequest = new GooglePaymentRequest()
            .transactionInfo(TransactionInfo.newBuilder()
                    .setTotalPrice((String) arg.get("totalPrice"))
                    .setCurrencyCode((String) arg.get("currencyCode"))
                    .setTotalPriceStatus(WalletConstants.TOTAL_PRICE_STATUS_FINAL)
                    .build())
            .billingAddressRequired((Boolean) arg.get("billingAddressRequired"))
            .googleMerchantId((String) arg.get("merchantID"));
    dropInRequest.googlePaymentRequest(googlePaymentRequest);
  }

  private static void readPayPalParameters(DropInRequest dropInRequest, MethodCall call) {
    HashMap<String, Object> arg = call.argument("paypalRequest");
    if (arg == null) {
      dropInRequest.disablePayPal();
      return;
    }
    String amount = (String) arg.get("amount");
    PayPalRequest paypalRequest = amount == null ? new PayPalRequest() : new PayPalRequest(amount);
    paypalRequest.currencyCode((String) arg.get("currencyCode"))
            .displayName((String) arg.get("displayName"))
            .billingAgreementDescription((String) arg.get("billingAgreementDescription"));
    dropInRequest.paypalRequest(paypalRequest);
  }

  @Override
  public boolean onActivityResult(int requestCode, int resultCode, Intent data)  {
    if (activeResult == null)
      return false;

    switch (requestCode) {
      case DROP_IN_REQUEST_CODE:
        if (resultCode == Activity.RESULT_OK) {
          DropInResult dropInResult = data.getParcelableExtra(DropInResult.EXTRA_DROP_IN_RESULT);
          PaymentMethodNonce paymentMethodNonce = dropInResult.getPaymentMethodNonce();
          HashMap<String, Object> result = new HashMap<String, Object>();

          HashMap<String, Object> nonceResult = new HashMap<String, Object>();
          nonceResult.put("nonce", paymentMethodNonce.getNonce());
          nonceResult.put("typeLabel", paymentMethodNonce.getTypeLabel());
          nonceResult.put("description", paymentMethodNonce.getDescription());
          nonceResult.put("isDefault", paymentMethodNonce.isDefault());

          result.put("paymentMethodNonce", nonceResult);
          result.put("deviceData", dropInResult.getDeviceData());
          activeResult.success(result);
        } else if (resultCode == Activity.RESULT_CANCELED) {
          activeResult.success(null);
        } else {
          Exception error = (Exception) data.getSerializableExtra(DropInActivity.EXTRA_ERROR);
          activeResult.error("braintree_error", error.getMessage(), null);
        }
        activeResult = null;
        return true;
      default:
        return false;
    }
  }
}