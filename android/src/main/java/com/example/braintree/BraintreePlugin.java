package com.example.braintree;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener;

import android.app.Activity;
import android.content.Intent;

import com.braintreepayments.api.dropin.DropInActivity;
import com.braintreepayments.api.dropin.DropInRequest;
import com.braintreepayments.api.dropin.DropInResult;

import java.util.HashMap;
import java.util.Map;

/** BraintreePlugin */
public class BraintreePlugin implements MethodCallHandler, ActivityResultListener {
  private static final int DROP_IN_REQUEST_CODE = 0x1337;

  private Activity activity;
  private Result activeResult;

  public BraintreePlugin(Registrar registrar) {
    registrar.addActivityResultListener(this);
    activity = registrar.activity();
  }

  /** Plugin registration. */
  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), "braintree");
    channel.setMethodCallHandler(new BraintreePlugin(registrar));
  }

  @Override
  public void onMethodCall(MethodCall call, Result result) {
    if (call.method.equals("getPlatformVersion")) {
      result.success("Android " + android.os.Build.VERSION.RELEASE);
    } else if (call.method.equals("launchDropIn")) {
      String clientToken = call.argument("clientToken");
      DropInRequest dropInRequest = new DropInRequest()
              .clientToken(clientToken)
              .collectDeviceData((Boolean) call.argument("collectDeviceData"));
      this.activeResult = result;
      activity.startActivityForResult(dropInRequest.getIntent(activity), DROP_IN_REQUEST_CODE);
    } else {
      result.notImplemented();
    }
  }

  @Override
  public boolean onActivityResult(int requestCode, int resultCode, Intent data)  {
    switch (requestCode) {
      case DROP_IN_REQUEST_CODE:
        if (resultCode == Activity.RESULT_OK) {
          DropInResult dropInResult = data.getParcelableExtra(DropInResult.EXTRA_DROP_IN_RESULT);
          Map map = new HashMap<String, String>();
          map.put("nonce", dropInResult.getPaymentMethodNonce().getNonce());
          map.put("nonceTypeLabel", dropInResult.getPaymentMethodNonce().getTypeLabel());
          map.put("nonceDescription", dropInResult.getPaymentMethodNonce().getDescription());
          map.put("nonceIsDefault", dropInResult.getPaymentMethodNonce().isDefault());
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
