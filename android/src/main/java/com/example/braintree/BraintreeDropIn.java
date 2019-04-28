package com.example.braintree;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener;
import io.flutter.plugin.common.PluginRegistry.Registrar;

import android.app.Activity;
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

public class BraintreeDropIn implements MethodCallHandler, ActivityResultListener {
  private static final int DROP_IN_REQUEST_CODE = 0x1337;

  private Activity activity;
  private Result activeResult;

  public BraintreeDropIn(Registrar registrar) {
      activity = registrar.activity();
      registrar.addActivityResultListener(this);
  }

  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), "braintree");
    channel.setMethodCallHandler(new BraintreeDropIn(registrar));
  }

  @Override
  public void onMethodCall(MethodCall call, Result result) {
    if (call.method.equals("startDropIn")) {
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
      // if (!((Boolean) call.argument("cardEnabled")))
      //   dropInRequest.disableCard();


      this.activeResult = result;
      activity.startActivityForResult(dropInRequest.getIntent(activity), DROP_IN_REQUEST_CODE);
    } else {
      result.notImplemented();
    }
  }

  private void readGooglePaymentParameters(DropInRequest dropInRequest, MethodCall call) {
    if (!((Boolean) call.argument("googlePaymentEnabled")))
      return;
    GooglePaymentRequest googlePaymentRequest = new GooglePaymentRequest()
            .transactionInfo(TransactionInfo.newBuilder()
                    .setTotalPrice((String) call.argument("googlePaymentRequest_totalPrice"))
                    .setCurrencyCode((String) call.argument("googlePaymentRequest_currencyCode"))
                    .setTotalPriceStatus(WalletConstants.TOTAL_PRICE_STATUS_FINAL)
                    .build())
            .billingAddressRequired((Boolean) call.argument("googlePaymentRequest_billingAddressRequired"))
            .googleMerchantId((String) call.argument("googlePaymentRequest_merchantID"));
    dropInRequest.googlePaymentRequest(googlePaymentRequest);
  }

  private void readPayPalParameters(DropInRequest dropInRequest, MethodCall call) {
    if (!((Boolean) call.argument("paypalEnabled")))
      return;
    String amount = call.argument("paypalRequest_amount");
    PayPalRequest paypalRequest = amount == null ? new PayPalRequest() : new PayPalRequest(amount);
    paypalRequest.currencyCode((String) call.argument("paypalRequest_currencyCode"))
            .displayName((String) call.argument("paypalRequest_displayName"))
            .billingAgreementDescription((String) call.argument("paypalRequest_billingAgreementDescription"));
    dropInRequest.paypalRequest(paypalRequest);
  }

  @Override
  public boolean onActivityResult(int requestCode, int resultCode, Intent data)  {
    switch (requestCode) {
      case DROP_IN_REQUEST_CODE:
        if (resultCode == Activity.RESULT_OK) {
          DropInResult dropInResult = data.getParcelableExtra(DropInResult.EXTRA_DROP_IN_RESULT);
          PaymentMethodNonce paymentMethodNonce = dropInResult.getPaymentMethodNonce();
          HashMap<String, Object> map = new HashMap<String, Object>();
          map.put("paymentMethodNonce_nonce", paymentMethodNonce.getNonce());
          map.put("paymentMethodNonce_typeLabel", paymentMethodNonce.getTypeLabel());
          map.put("paymentMethodNonce_description", paymentMethodNonce.getDescription());
          map.put("paymentMethodNonce_isDefault", paymentMethodNonce.isDefault());
          map.put("deviceData", dropInResult.getDeviceData());
          activeResult.success(map);
        } else if (resultCode == Activity.RESULT_CANCELED) {
          activeResult.success(null);
        } else {
          Exception error = (Exception) data.getSerializableExtra(DropInActivity.EXTRA_ERROR);
          activeResult.error("DROP_IN_ERROR", error.getMessage(), null);
        }
        return true;
      default:
        return false;
    }
  }
}