import 'package:flutter/services.dart';
import 'dart:async';

import 'drop_in_request.dart';
import 'drop_in_result.dart';

class BraintreeDropIn {
  static const MethodChannel _channel = const MethodChannel('braintree');

  /// Launches the Braintree Drop-in UI.
  ///
  /// The required options are inside the [request] object.
  /// See its documentation for more information.
  ///
  /// Returns a Future of a `BraintreeDropInResult` containing
  /// all the relevant information, or `null` if the payment was canceled.
  static Future<BraintreeDropInResult> start(
      BraintreeDropInRequest request) async {
    var result = await _channel.invokeMethod<Map>(
      'startDropIn',
      _mapFromRequest(request),
    );
    if (result == null) {
      return null;
    }
    return _resultFromMap(result);
  }

  static Map<String, dynamic> _mapFromRequest(BraintreeDropInRequest request) {
    var gpr = request.googlePaymentRequest;
    var ppr = request.paypalRequest;
    return {
      'clientToken': request.clientToken,
      'tokenizationKey': request.tokenizationKey,
      'amount': request.amount,
      'collectDeviceData': request.collectDeviceData ?? false,
      'requestThreeDSecureVerification':
          request.requestThreeDSecureVerification ?? false,
      'googlePaymentEnabled': gpr != null,
      'googlePaymentRequest_totalPrice': gpr != null ? gpr.totalPrice : null,
      'googlePaymentRequest_currencyCode':
          gpr != null ? gpr.currencyCode : null,
      'googlePaymentRequest_billingAddressRequired':
          gpr != null ? (gpr.billingAddressRequired ?? false) : null,
      'googlePaymentRequest_googleMerchantID':
          gpr != null ? gpr.googleMerchantID : null,
      'paypalEnabled': ppr != null,
      'paypalRequest_amount': ppr != null ? ppr.amount : null,
      'paypalRequest_currencyCode': ppr != null ? ppr.currencyCode : null,
      'paypalRequest_displayName': ppr != null ? ppr.displayName : null,
      'paypalRequest_billingAgreementDescription':
          ppr != null ? ppr.billingAgreementDescription : null,
      'venmoEnabled': request.venmoEnabled ?? false,
      'cardEnabled': request.cardEnabled ?? false,
      'maskCardNumber': request.maskCardNumber ?? false,
      'maskSecurityCode': request.maskSecurityCode ?? false,
      'vaultManagerEnabled': request.vaultManagerEnabled ?? false,
    };
  }

  static BraintreeDropInResult _resultFromMap(Map map) {
    return BraintreeDropInResult.create(
      paymentMethodNonce: BraintreePaymentMethodNonce.create(
        nonce: map['paymentMethodNonce_nonce'],
        typeLabel: map['paymentMethodNonce_typeLabel'],
        description: map['paymentMethodNonce_description'],
        isDefault: map['paymentMethodNonce_isDefault'],
      ),
      deviceData: map['deviceData'],
    );
  }
}
