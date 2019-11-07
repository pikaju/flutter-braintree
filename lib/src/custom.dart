import 'package:flutter/services.dart';

import 'request.dart';
import 'result.dart';

class Braintree {
  static const MethodChannel _kChannel =
      const MethodChannel('flutter_braintree.custom');

  const Braintree._();

  /// Tokenizes a credit card.
  ///
  /// [authorization] must be either a valid client token or a valid tokenization key.
  /// [request] should contain all the credit card information necessary for tokenization.
  ///
  /// Returns a [Future] that resolves to a [BraintreePaymentMethodNonce] if the tokenization was successful.
  static Future<BraintreePaymentMethodNonce> tokenizeCreditCard(
    String authorization,
    BraintreeCreditCardRequest request,
  ) async {
    assert(authorization != null);
    assert(request != null);
    final result = await _kChannel.invokeMethod('tokenizeCreditCard', {
      'authorization': authorization,
      'request': request.toJson(),
    });
    return BraintreePaymentMethodNonce.fromJson(result);
  }

  /// Requests a PayPal payment method nonce.
  ///
  /// [authorization] must be either a valid client token or a valid tokenization key.
  /// [request] should contain all the information necessary for the PayPal request.
  ///
  /// Returns a [Future] that resolves to a [BraintreePaymentMethodNonce] if the user confirmed the request,
  /// or `null` if the user canceled the Vault or Checkout flow.
  static Future<BraintreePaymentMethodNonce> requestPaypalNonce(
    String authorization,
    BraintreePayPalRequest request,
  ) async {
    assert(authorization != null);
    assert(request != null);
    final result = await _kChannel.invokeMethod('requestPaypalNonce', {
      'authorization': authorization,
      'request': request.toJson(),
    });
    return BraintreePaymentMethodNonce.fromJson(result);
  }
}
