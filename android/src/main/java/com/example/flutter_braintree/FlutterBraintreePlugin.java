package com.example.flutter_braintree;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;

import com.braintreepayments.api.dropin.DropInActivity;
import com.braintreepayments.api.dropin.DropInRequest;
import com.braintreepayments.api.dropin.DropInResult;
import com.braintreepayments.api.models.PaymentMethodNonce;

import java.util.HashMap;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener;

public class FlutterBraintreePlugin implements MethodCallHandler, ActivityResultListener {
  private static final int CUSTOM_ACTIVITY_REQUEST_CODE = 0x420;

  private Activity activity;
  private Context context;
  private Result activeResult;

  public FlutterBraintreePlugin(Registrar registrar) {
    activity = registrar.activity();
    context = registrar.context();
    registrar.addActivityResultListener(this);
  }

  public static void registerWith(Registrar registrar) {
    FlutterBraintreeDropIn.registerWith(registrar);
    final MethodChannel channel = new MethodChannel(registrar.messenger(), "flutter_braintree.custom");
    channel.setMethodCallHandler(new FlutterBraintreePlugin(registrar));
  }

  @Override
  public void onMethodCall(MethodCall call, Result result) {
    if (activeResult != null) {
      result.error("already_running", "Cannot launch another custom activity while one is already running.", null);
      return;
    }
    activeResult = result;

    if (call.method.equals("tokenizeCreditCard")) {
      String authorization = call.argument("authorization");
      Intent intent = new Intent(activity, FlutterBraintreeCustom.class);
      intent.putExtra("type", "tokenizeCreditCard");
      intent.putExtra("authorization", (String) call.argument("authorization"));
      HashMap<String, Object> request = (HashMap<String, Object>) call.argument("request");
      intent.putExtra("cardNumber", (String) request.get("cardNumber"));
      intent.putExtra("expirationMonth", (String) request.get("expirationMonth"));
      intent.putExtra("expirationYear", (String) request.get("expirationYear"));
      activity.startActivityForResult(intent, CUSTOM_ACTIVITY_REQUEST_CODE);
    } else {
      result.notImplemented();
      activeResult = null;
    }
  }

  @Override
  public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
    switch (requestCode) {
      case CUSTOM_ACTIVITY_REQUEST_CODE:
        if (resultCode == Activity.RESULT_OK) {
          String type = data.getStringExtra("type");
          if (type.equals("paymentMethodNonce")) {
            activeResult.success(data.getSerializableExtra("paymentMethodNonce"));
          } else {
            Exception error = new Exception("Invalid activity result type.");
            activeResult.error("error", error.getMessage(), null);
          }
        } else if (resultCode == Activity.RESULT_CANCELED) {
          activeResult.success(null);
        }  else {
          Exception error = (Exception) data.getSerializableExtra("error");
          activeResult.error("error", error.getMessage(), null);
        }
        activeResult = null;
        return true;
      default:
        return false;
    }
  }
}
