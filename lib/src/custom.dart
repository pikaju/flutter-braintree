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
  static Future<BraintreePaymentMethodNonce?> tokenizeCreditCard(
    String authorization,
    BraintreeCreditCardRequest request,
  ) async {
    final result = await _kChannel.invokeMethod('tokenizeCreditCard', {
      'authorization': authorization,
      'request': request.toJson(),
    });
    if (result == null) return null;
    return BraintreePaymentMethodNonce.fromJson(result);
  }

  /// Requests a PayPal payment method nonce.
  ///
  /// [authorization] must be either a valid client token or a valid tokenization key.
  /// [request] should contain all the information necessary for the PayPal request.
  ///
  /// Returns a [Future] that resolves to a [BraintreePaymentMethodNonce] if the user confirmed the request,
  /// or `null` if the user canceled the Vault or Checkout flow.
  static Future<BraintreePaymentMethodNonce?> requestPaypalNonce(
    String authorization,
    BraintreePayPalRequest request,
  ) async {
    final result = await _kChannel.invokeMethod('requestPaypalNonce', {
      'authorization': authorization,
      'request': request.toJson(),
    });
    if (result == null) return null;
    return BraintreePaymentMethodNonce.fromJson(result);
  }

  static Future<BraintreeDeviceData?> requestDeviceData(
    String authorization,
  ) async {
    final result = await _kChannel.invokeMethod('collectDeviceData', {
      'authorization': authorization,
    });
    if (result == null) return null;
    return BraintreeDeviceData.fromJson(result);
  }

  static Future<String> isGooglePayReady(
    String authorization,
  ) async {
    final result = await _kChannel.invokeMethod('isGooglePayReady', {
      'authorization': authorization,
    });
    return result;
  }

  static Future<BraintreePaymentMethodNonce?> googlePayPayment(
    String authorization,
    BraintreeGooglePaymentRequest request,
  ) async {
    final result = await _kChannel.invokeMethod('googlePayPayment', {
      'authorization': authorization,
      'request': request.toJson(),
    });
    if (result == null) return null;
    return BraintreePaymentMethodNonce.fromJson(result);
  }

  static Future<BraintreePaymentMethodNonce?> requestApplePay(
      String authorization,
      BraintreeApplePayRequest request,
      ) async {
    final result = await _kChannel.invokeMethod('applePayPayment', {
      'authorization': authorization,
      'request': request.toJson(),
    });
    if (result == null) return null;
    return BraintreePaymentMethodNonce.fromJson(result);
  }
}
