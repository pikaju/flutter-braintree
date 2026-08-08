import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import 'credit_card_form_screen.dart';
import 'custom.dart';
import 'request.dart';
import 'result.dart';

/// Presents the cross-platform Flutter replacement for the native Drop-in UI.
///
/// Offers the payment options enabled in [request] (card, PayPal, Apple Pay) and
/// resolves to a [BraintreeDropInResult], or `null` if the user dismissed the sheet.
///
/// Used on every platform except Android, which retains its native Drop-in flow.
Future<BraintreeDropInResult?> showBraintreeDropInSheet(
  BuildContext context,
  BraintreeDropInRequest request,
) {
  return showModalBottomSheet<BraintreeDropInResult?>(
    context: context,
    isScrollControlled: true,
    builder: (_) => BraintreeDropInSheet(request: request),
  );
}

/// The payment-method picker rendered by [showBraintreeDropInSheet].
class BraintreeDropInSheet extends StatelessWidget {
  const BraintreeDropInSheet({super.key, required this.request});

  final BraintreeDropInRequest request;

  String? get _authorization => request.clientToken ?? request.tokenizationKey;

  bool get _isApplePaySupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _selectCard(BuildContext context) async {
    final authorization = _authorization;
    if (authorization == null) return;

    final nonce = await Navigator.of(context).push<BraintreePaymentMethodNonce?>(
      MaterialPageRoute(
        builder: (_) => CreditCardFormScreen(
          authorization: authorization,
          amount: request.amount ?? '0',
          collectDeviceData: request.collectDeviceData,
          requestThreeDSecureVerification: request.requestThreeDSecureVerification,
          billingAddress: request.billingAddress,
          email: request.email,
        ),
      ),
    );

    if (nonce != null && context.mounted) {
      Navigator.of(context).pop(_resultFor(nonce));
    }
  }

  Future<void> _selectPayPal(BuildContext context) async {
    final authorization = _authorization;
    final paypalRequest = request.paypalRequest;
    if (authorization == null || paypalRequest == null) return;

    final nonce = await Braintree.requestPaypalNonce(
      authorization,
      paypalRequest,
      collectDeviceData: request.collectDeviceData,
    );

    if (context.mounted) {
      Navigator.of(context).pop(nonce != null ? _resultFor(nonce) : null);
    }
  }

  Future<void> _selectApplePay(BuildContext context) async {
    final authorization = _authorization;
    final applePayRequest = request.applePayRequest;
    if (authorization == null || applePayRequest == null) return;

    final nonce = await Braintree.requestApplePayNonce(
      authorization,
      applePayRequest,
      collectDeviceData: request.collectDeviceData,
    );

    if (context.mounted) {
      Navigator.of(context).pop(nonce != null ? _resultFor(nonce) : null);
    }
  }

  BraintreeDropInResult _resultFor(BraintreePaymentMethodNonce nonce) {
    return BraintreeDropInResult(
      paymentMethodNonce: nonce,
      deviceData: nonce.deviceData,
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = <Widget>[
      if (request.cardEnabled)
        ListTile(
          leading: const Icon(Icons.credit_card),
          title: const Text('Card'),
          onTap: () => _selectCard(context),
        ),
      if (request.paypalEnabled && request.paypalRequest != null)
        ListTile(
          leading: const Icon(Icons.account_balance_wallet),
          title: const Text('PayPal'),
          onTap: () => _selectPayPal(context),
        ),
      if (_isApplePaySupported && request.applePayRequest != null)
        ListTile(
          leading: const Icon(Icons.apple),
          title: const Text('Apple Pay'),
          onTap: () => _selectApplePay(context),
        ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                'Select a payment method',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...options,
          ],
        ),
      ),
    );
  }
}
