library braintree;

export 'src/drop_in.dart';
export 'src/drop_in_request.dart';
export 'src/drop_in_result.dart';

import 'dart:async';
import 'package:flutter/services.dart';

class Braintree {
  static const MethodChannel _channel = const MethodChannel('braintree');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
