library braintree;

export 'src/braintree_drop_in.dart';

import 'dart:async';
import 'package:flutter/services.dart';

class Braintree {
  static const MethodChannel _channel = const MethodChannel('braintree');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
