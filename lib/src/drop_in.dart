import 'package:flutter/widgets.dart';
import 'dart:async';

import 'drop_in_sheet.dart';
import 'request.dart';
import 'result.dart';

class BraintreeDropIn {
  const BraintreeDropIn._();

  /// Launches the Braintree Drop-in payment selection.
  ///
  /// On every platform this presents a cross-platform Flutter payment sheet, so
  /// a [BuildContext] is required. The native Drop-in SDKs have been removed:
  /// the iOS Drop-in SDK has no Braintree v7-compatible release, and the Android
  /// Drop-in SDK is deprecated (end-of-life 2027) in favour of the direct
  /// Braintree SDK, so both platforms now drive the Flutter sheet against the
  /// direct SDKs (iOS Braintree v7, Android Braintree v5).
  ///
  /// The required options can be placed inside the [request] object.
  /// See its documentation for more information.
  ///
  /// Returns a Future that resolves to a [BraintreeDropInResult] containing
  /// all the relevant information, or `null` if the selection was canceled.
  static Future<BraintreeDropInResult?> start(
    BuildContext context,
    BraintreeDropInRequest request,
  ) async {
    return showBraintreeDropInSheet(context, request);
  }
}
