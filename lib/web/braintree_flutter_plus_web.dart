import 'dart:async';
import 'dart:developer';
import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart';

class BraintreeFlutterPlusWeb {
  static void registerWith(Registrar registrar) {
    final channel = MethodChannel(
      'flutter_braintree.custom',
      const StandardMethodCodec(),
      registrar,
    );
    channel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<Map<String, Object?>?> _handleMethodCall(
    MethodCall call,
  ) async {
    log('[BraintreeFlutterPlusWeb] → ${call.method}');
    final args = call.arguments as Map<Object?, Object?>;
    return switch (call.method) {
      'tokenizeCreditCard' => await _CreditCardTokenizer.from(args).tokenize(),
      'requestPaypalNonce' => await _PayPalTokenizer.from(args).tokenize(),
      _ => throw PlatformException(
        code: 'unimplemented',
        message: '${call.method} is not implemented on web',
      ),
    };
  }
}

final class _CreditCardTokenizer {
  final String authorization;
  final String cardNumber;
  final String expirationMonth;
  final String expirationYear;
  final String cvv;
  final String? cardholderName;
  final String amount;

  const _CreditCardTokenizer({
    required this.authorization,
    required this.cardNumber,
    required this.expirationMonth,
    required this.expirationYear,
    required this.cvv,
    required this.cardholderName,
    required this.amount,
  });

  factory _CreditCardTokenizer.from(Map<Object?, Object?> args) {
    final req = args['request'] as Map<Object?, Object?>;
    return _CreditCardTokenizer(
      authorization: args['authorization'] as String,
      cardNumber: req['cardNumber'] as String,
      expirationMonth: req['expirationMonth'] as String,
      expirationYear: req['expirationYear'] as String,
      cvv: req['cvv'] as String,
      cardholderName: req['cardholderName'] as String?,
      amount: req['amount'] as String,
    );
  }

  Future<Map<String, dynamic>> tokenize() async {
    await _loadScript('$_cdnBase/client.min.js');

    final clientInstance = await _braintree.client
        .create({'authorization': authorization}.jsify()! as JSObject)
        .toDart
        .onError<JSObject>((e, _) => throw _jsError(e));

    final responseObj = await clientInstance
        .request(
          {
                'endpoint': 'payment_methods/credit_cards',
                'method': 'post',
                'data': {
                  'creditCard': {
                    'number': cardNumber,
                    'expirationDate': '$expirationMonth/$expirationYear',
                    'cvv': cvv,
                    if (cardholderName != null)
                      'cardholderName': cardholderName,
                  },
                },
              }.jsify()!
              as JSObject,
        )
        .toDart
        .onError<JSObject>((e, _) => throw _jsError(e));

    final card =
        (responseObj as _CardTokenizeResponse).creditCards.toDart.first;

    return {
      'nonce': card.nonce.toDart,
      'typeLabel': card.details.cardType.toDart,
      'description': card.description.toDart,
      'isDefault': false,
      'paypalPayerId': null,
      'amount': amount,
    };
  }
}

final class _PayPalTokenizer {
  final String authorization;
  final String? amount;
  final String currencyCode;
  final String intent; // 'order' | 'sale' | 'authorize'
  final String? displayName;
  final String? billingAgreementDescription;

  const _PayPalTokenizer({
    required this.authorization,
    required this.amount,
    required this.currencyCode,
    required this.intent,
    required this.displayName,
    required this.billingAgreementDescription,
  });

  factory _PayPalTokenizer.from(Map<Object?, Object?> args) {
    final req = args['request'] as Map<Object?, Object?>;
    return _PayPalTokenizer(
      authorization: args['authorization'] as String,
      amount: req['amount'] as String?,
      currencyCode: (req['currencyCode'] as String?) ?? 'USD',
      intent: (req['payPalPaymentIntent'] as String?) ?? 'authorize',
      displayName: req['displayName'] as String?,
      billingAgreementDescription:
          req['billingAgreementDescription'] as String?,
    );
  }

  Future<Map<String, dynamic>?> tokenize() async {
    final isVault = amount == null || amount!.isEmpty;

    await _loadScript('$_cdnBase/client.min.js');
    await _loadScript('$_cdnBase/paypal-checkout.min.js');

    final clientInstance = await _braintree.client
        .create({'authorization': authorization}.jsify()! as JSObject)
        .toDart
        .onError<JSObject>((e, _) => throw _jsError(e));

    final ppCheckout = await _braintree.paypalCheckout
        .create({'client': clientInstance}.jsify()! as JSObject)
        .toDart
        .onError<JSObject>((e, _) => throw _jsError(e));

    final clientId = ppCheckout.clientId.toDart;
    final sdkParams = StringBuffer('client-id=$clientId&components=buttons');
    if (isVault) {
      sdkParams.write('&vault=true');
    } else {
      sdkParams.write('&currency=$currencyCode&intent=$intent');
    }

    if (document.querySelector('script[data-bt-paypal-sdk]') == null) {
      final paypalScript = HTMLScriptElement();
      paypalScript.src = 'https://www.paypal.com/sdk/js?$sdkParams';
      paypalScript.setAttribute('data-bt-paypal-sdk', 'true');
      final c = Completer<void>();
      paypalScript.onload = ((Event _) {
        log('[BraintreeFlutterPlusWeb] PayPal SDK loaded');
        c.complete();
      }).toJS;
      paypalScript.onerror = ((Event _) {
        final err = PlatformException(
          code: 'braintree_script_load_error',
          message:
              'Failed to load PayPal SDK: ${paypalScript.src} — check DevTools → Network',
        );
        log('[BraintreeFlutterPlusWeb] ✗ ${err.message}');
        c.completeError(err);
      }).toJS;
      document.head!.appendChild(paypalScript);
      await c.future;
    }

    final overlay = _createOverlay();
    document.body!.appendChild(overlay);

    final completer = Completer<Map<String, dynamic>?>();

    overlay
        .querySelector('#_bt_paypal_close')!
        .addEventListener(
          'click',
          ((Event _) {
            overlay.remove();
            if (!completer.isCompleted) completer.complete(null);
          }).toJS,
        );

    final createPaymentOptions = <String, Object?>{
      'flow': isVault ? 'vault' : 'checkout',
      if (!isVault) ...{
        'amount': amount,
        'currency': currencyCode,
        'intent': intent,
      },
      if (displayName != null) 'displayName': displayName,
      if (billingAgreementDescription != null)
        'description': billingAgreementDescription,
    };

    final buttonsOptions = <String, JSAny>{
      if (isVault)
        'createBillingAgreement': (() => ppCheckout.createPayment(
          createPaymentOptions.jsify()! as JSObject,
        )).toJS
      else
        'createOrder': (() => ppCheckout.createPayment(
          createPaymentOptions.jsify()! as JSObject,
        )).toJS,
      'onApprove': (JSObject data, JSObject _) {
        ppCheckout
            .tokenizePayment(data)
            .toDart
            .then((payload) {
              overlay.remove();
              if (!completer.isCompleted) {
                final details = payload.details;
                completer.complete({
                  'nonce': payload.nonce.toDart,
                  'typeLabel': 'PayPal',
                  'description': details.email?.toDart ?? '',
                  'isDefault': false,
                  'paypalPayerId': details.payerId?.toDart,
                  'amount': amount,
                });
              }
            })
            .catchError((Object e) {
              overlay.remove();
              if (!completer.isCompleted) {
                completer.completeError(_jsError(e as JSObject));
              }
            }, test: (e) => e is JSObject);
      }.toJS,
      'onCancel': () {
        overlay.remove();
        if (!completer.isCompleted) completer.complete(null);
      }.toJS,
      'onError': (_JSError err) {
        final code = err.code?.toDart ?? '';
        overlay.remove();
        if (!completer.isCompleted) {
          if (code == 'PAYPAL_POPUP_CLOSED' ||
              code == 'PAYPAL_CANCELED_BY_BUYER') {
            completer.complete(null);
          } else {
            completer.completeError(_jsError(err));
          }
        }
      }.toJS,
    };

    try {
      await _paypal.Buttons(
        buttonsOptions.jsify()! as JSObject,
      ).render('#_bt_paypal_button_container'.toJS).toDart;
    } on JSObject catch (e) {
      overlay.remove();
      throw _jsError(e);
    }

    return completer.future;
  }

  static HTMLDivElement _createOverlay() {
    final overlay = document.createElement('div') as HTMLDivElement;
    overlay.id = '_bt_paypal_overlay';
    overlay.setAttribute(
      'style',
      'position:fixed;top:0;left:0;width:100%;height:100%;'
          'background:rgba(0,0,0,0.5);z-index:2147483647;'
          'display:flex;align-items:center;justify-content:center;',
    );

    final card = document.createElement('div') as HTMLDivElement;
    card.setAttribute(
      'style',
      'background:#fff;border-radius:8px;padding:24px;'
          'min-width:320px;box-shadow:0 4px 20px rgba(0,0,0,0.3);',
    );

    final header = document.createElement('div') as HTMLDivElement;
    header.setAttribute(
      'style',
      'display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;',
    );

    final title = document.createElement('span') as HTMLSpanElement;
    title.setAttribute(
      'style',
      'font-size:16px;font-weight:600;font-family:sans-serif;',
    );
    title.textContent = 'Pay with PayPal';

    final closeBtn = document.createElement('button') as HTMLButtonElement;
    closeBtn.id = '_bt_paypal_close';
    closeBtn.setAttribute(
      'style',
      'border:none;background:none;cursor:pointer;font-size:22px;line-height:1;color:#555;',
    );
    closeBtn.setAttribute('aria-label', 'Close');
    closeBtn.textContent = '\u00d7';

    header.appendChild(title);
    header.appendChild(closeBtn);

    final btnContainer = document.createElement('div') as HTMLDivElement;
    btnContainer.id = '_bt_paypal_button_container';

    card.appendChild(header);
    card.appendChild(btnContainer);
    overlay.appendChild(card);

    return overlay;
  }
}

const _sdkVersion = '3.139.0';
const _cdnBase = 'https://js.braintreegateway.com/web/$_sdkVersion/js';

Future<void> _loadScript(String src) async {
  if (document.querySelector('script[src="$src"]') != null) {
    log('[BraintreeFlutterPlusWeb] script already present: $src');
    return;
  }
  log('[BraintreeFlutterPlusWeb] loading script: $src');
  final completer = Completer<void>();
  final script = HTMLScriptElement();
  script.src = src;
  script.defer = true;
  script.onload = ((Event _) {
    log('[BraintreeFlutterPlusWeb] script loaded: $src');
    completer.complete();
  }).toJS;
  script.onerror = ((Event _) {
    log('[BraintreeFlutterPlusWeb] ✗ failed to load script: $src');
    completer.completeError(
      PlatformException(
        code: 'braintree_script_load_error',
        message: 'Failed to load $src',
      ),
    );
  }).toJS;
  document.head!.appendChild(script);
  await completer.future;
}

// Converts a JS Promise rejection (always a JSObject from Braintree) into a
// PlatformException. Method channels can't serialize JSObject — that's the
// only reason this helper exists.
PlatformException _jsError(JSObject e) {
  final err = e as _JSError;
  final code = err.code?.toDart ?? 'braintree_error';
  final message = err.message?.toDart ?? 'Unknown Braintree JS error';
  log('[BraintreeFlutterPlusWeb] ✗ [$code] $message');
  return PlatformException(code: code, message: message);
}

extension type _JSError._(JSObject _) implements JSObject {
  external JSString? get code;
  external JSString? get message;
}

@JS('braintree')
external _BraintreeNS get _braintree;

extension type _BraintreeNS._(JSObject _) implements JSObject {
  external _ClientModule get client;
  external _PPCheckoutModule get paypalCheckout;
}

extension type _ClientModule._(JSObject _) implements JSObject {
  external JSPromise<_ClientInstance> create(JSObject options);
}

extension type _ClientInstance._(JSObject _) implements JSObject {
  external JSPromise<JSObject> request(JSObject options);
}

extension type _CardTokenizeResponse._(JSObject _) implements JSObject {
  external JSArray<_CardTokenizeResult> get creditCards;
}

extension type _CardTokenizeResult._(JSObject _) implements JSObject {
  external JSString get nonce;
  external JSString get description; // e.g. "ending in 11"
  external _CardTokenizeDetails get details;
}

extension type _CardTokenizeDetails._(JSObject _) implements JSObject {
  external JSString get cardType; // e.g. "Visa", "MasterCard"
}

extension type _PPCheckoutModule._(JSObject _) implements JSObject {
  external JSPromise<_PPCheckoutInstance> create(JSObject options);
}

extension type _PPCheckoutInstance._(JSObject _) implements JSObject {
  external JSString get clientId;
  external JSPromise<JSAny> createPayment(JSObject options);
  external JSPromise<_PPTokenizePayload> tokenizePayment(JSObject data);
}

extension type _PPTokenizePayload._(JSObject _) implements JSObject {
  external JSString get nonce;
  external _PPDetails get details;
}

extension type _PPDetails._(JSObject _) implements JSObject {
  external JSString? get email;
  external JSString? get payerId;
}

@JS('paypal')
external _PayPalNS get _paypal;

extension type _PayPalNS._(JSObject _) implements JSObject {
  external _ButtonsComponent Buttons(JSObject options);
}

extension type _ButtonsComponent._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> render(JSString selector);
}
