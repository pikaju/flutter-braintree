import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class BraintreeDropIn {
  static const MethodChannel _channel = const MethodChannel('braintree');

  /// Launches the Braintree Drop-in UI.
  /// Returns a Future of a BraintreeDropInResult containing
  /// all the relevant information, or null if the payment was canceled.
  static Future<BraintreeDropInResult> launch(
      {@required String clientToken, bool collectDeviceData = false}) async {
    var result = await _channel.invokeMethod<Map>(
      'launchDropIn',
      {
        'clientToken': clientToken,
        'collectDeviceData': collectDeviceData,
      },
    );
    if (result == null) {
      return null;
    }
    var paymentMethodNonce = BraintreePaymentMethodNonce._create(
      nonce: result['nonce'],
      typeLabel: result['nonceTypeLabel'],
      description: result['nonceDescription'],
      isDefault: result['nonceIsDefault'],
    );
    return BraintreeDropInResult._create(
      paymentMethodNonce: paymentMethodNonce,
      deviceData: result['deviceData'],
    );
  }
}

class BraintreePaymentMethodNonce {
  /// The nonce generated for this payment method by the Braintree gateway. The nonce will represent
  /// this PaymentMethod for the purposes of creating transactions and other monetary actions.
  final String nonce;

  /// The type of this PaymentMethod for displaying to a customer, e.g. 'Visa'. Can be used for displaying appropriate logos, etc.
  final String typeLabel;

  /// The description of this PaymentMethod for displaying to a customer, e.g. 'Visa ending in...'.
  final String description;

  /// True if this payment method is the default for the current customer, false otherwise.
  final bool isDefault;

  BraintreePaymentMethodNonce._create(
      {this.nonce, this.typeLabel, this.description, this.isDefault});
}

class BraintreeDropInResult {
  /// The payment method nonce containing all relevant information for the payment.
  final BraintreePaymentMethodNonce paymentMethodNonce;

  /// String of device data. Null, if 'collectDeviceData' was set to false.
  final String deviceData;

  BraintreeDropInResult._create({this.paymentMethodNonce, this.deviceData});
}
