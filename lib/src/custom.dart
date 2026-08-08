import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'credit_card_form_screen.dart';
import 'request.dart';
import 'result.dart';

class Braintree {
  static const MethodChannel _kChannel = const MethodChannel('flutter_braintree.custom');

  const Braintree._();

  /// Tokenizes a credit card.
  ///
  /// [authorization] must be either a valid client token or a valid tokenization key.
  /// [request] should contain all the credit card information necessary for tokenization.
  ///
  /// Returns a [Future] that resolves to a [BraintreePaymentMethodNonce] if the tokenization was successful.
  static Future<BraintreePaymentMethodNonce?> tokenizeCreditCard(
    String authorization,
    BraintreeCreditCardRequest request, {
    bool collectDeviceData = false,
    bool requestThreeDSecureVerification = false,
    BraintreeBillingAddress? billingAddress,
    String? email,
  }) async {
    final result = await _kChannel.invokeMethod('tokenizeCreditCard', {
      'authorization': authorization,
      'request': request.toJson(),
      'collectDeviceData': collectDeviceData,
      'requestThreeDSecureVerification': requestThreeDSecureVerification,
      if (billingAddress != null) 'billingAddress': billingAddress.toJson(),
      if (email != null) 'email': email,
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
    BraintreePayPalRequest request, {
    bool collectDeviceData = false,
  }) async {
    final result = await _kChannel.invokeMethod('requestPaypalNonce', {
      'authorization': authorization,
      'request': request.toJson(),
      'collectDeviceData': collectDeviceData,
    });
    if (result == null) return null;
    return BraintreePaymentMethodNonce.fromJson(result);
  }

  /// Presents the native Apple Pay sheet and requests a payment method nonce.
  ///
  /// iOS only. [authorization] must be either a valid client token or a valid
  /// tokenization key. [request] should contain all Apple Pay information.
  ///
  /// Returns a [Future] that resolves to a [BraintreePaymentMethodNonce] if the
  /// user authorized the payment, or `null` if the Apple Pay sheet was canceled.
  static Future<BraintreePaymentMethodNonce?> requestApplePayNonce(
    String authorization,
    BraintreeApplePayRequest request, {
    bool collectDeviceData = false,
  }) async {
    final result = await _kChannel.invokeMethod('requestApplePayNonce', {
      'authorization': authorization,
      'request': request.toJson(),
      'collectDeviceData': collectDeviceData,
    });
    if (result == null) return null;
    return BraintreePaymentMethodNonce.fromJson(result);
  }

  static Future<BraintreePaymentMethodNonce?> showCreditCardForm(
    BuildContext context, {
    required String authorization,
    required String amount,
  }) {
    return Navigator.push<BraintreePaymentMethodNonce?>(
      context,
      MaterialPageRoute(
        builder: (context) => CreditCardFormScreen(
          authorization: authorization,
          amount: amount,
        ),
      ),
    );
  }
}
