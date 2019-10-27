package com.example.flutter_braintree;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

public class FlutterBraintreePlugin {
  public static void registerWith(Registrar registrar) {
    FlutterBraintreeDropIn.registerWith(registrar);
  }
}
