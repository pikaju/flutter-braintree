import 'package:flutter/material.dart';
import 'package:braintree_flutter_plus/braintree_flutter_plus.dart';

void main() => runApp(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.light,
          colorScheme: const ColorScheme(
            brightness: Brightness.light,
            primary: Colors.black,
            onPrimary: Colors.white,
            secondary: Colors.white,
            onSecondary: Colors.black,
            error: Color(0xff86151E),
            onError: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black,
          ),
          splashColor: Colors.transparent,
        ),
        home: MyApp(),
      ),
    );

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static final String tokenizationKey = 'sandbox_x65773jc_yhgk5ghs4hkpgq4f';

  void showNonce(BraintreePaymentMethodNonce nonce) {
    print('=== PayPal Response ===');
    print('Nonce: ${nonce.nonce}');
    print('Type Label: ${nonce.typeLabel}');
    print('Description: ${nonce.description}');
    print('Is Default: ${nonce.isDefault}');
    print('Amount: ${nonce.amount}');
    print('=====================');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Payment method nonce:'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Nonce: ${nonce.nonce}'),
            SizedBox(height: 16),
            Text('Type label: ${nonce.typeLabel}'),
            SizedBox(height: 16),
            Text('Description: ${nonce.description}'),
            if (nonce.amount != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text('Amount: ${nonce.amount}'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Braintree example app'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () async {
                var request = BraintreeDropInRequest(
                  tokenizationKey: tokenizationKey,
                  amount: '4.20',
                  collectDeviceData: true,
                  vaultManagerEnabled: true,
                  requestThreeDSecureVerification: false,
                  email: "test@email.com",
                  billingAddress: BraintreeBillingAddress(
                    givenName: "Jill",
                    surname: "Doe",
                    phoneNumber: "5551234567",
                    streetAddress: "555 Smith St",
                    extendedAddress: "#2",
                    locality: "Chicago",
                    region: "IL",
                    postalCode: "12345",
                    countryCodeAlpha2: "US",
                  ),
                  googlePaymentRequest: BraintreeGooglePaymentRequest(
                    totalPrice: '4.20',
                    currencyCode: 'USD',
                    billingAddressRequired: false,
                  ),
                  applePayRequest: BraintreeApplePayRequest(
                    currencyCode: 'USD',
                    supportedNetworks: [
                      ApplePaySupportedNetworks.visa,
                      ApplePaySupportedNetworks.masterCard,
                      // ApplePaySupportedNetworks.amex,
                      // ApplePaySupportedNetworks.discover,
                    ],
                    countryCode: 'US',
                    merchantIdentifier: '',
                    displayName: '',
                    paymentSummaryItems: [],
                  ),
                  paypalRequest: BraintreePayPalRequest(
                    amount: '4.20',
                    displayName: 'Example company',
                    // Android only: PayPal (Braintree v5) returns via an App Link.
                    // Replace with a domain you control + configure App Links.
                    // See BraintreePayPalRequest.appLinkReturnUrl.
                    appLinkReturnUrl: 'https://example.com/braintree-payments',
                  ),
                  cardEnabled: true,
                );
                final result = await BraintreeDropIn.start(context, request);
                if (result != null) {
                  showNonce(result.paymentMethodNonce);
                }
              },
              child: Text('LAUNCH NATIVE DROP-IN'),
            ),
            ElevatedButton(
              onPressed: () async {
                final request = BraintreeCreditCardRequest(
                  cardNumber: '4111111111111111',
                  expirationMonth: '12',
                  expirationYear: '2021',
                  cvv: '123',
                  amount: '4.20',
                );
                final result = await Braintree.tokenizeCreditCard(
                  tokenizationKey,
                  request,
                );
                if (result != null) {
                  showNonce(result);
                }
              },
              child: Text('TOKENIZE CREDIT CARD'),
            ),
            ElevatedButton(
              onPressed: () async {
                final request = BraintreePayPalRequest(
                  amount: null,
                  billingAgreementDescription: 'I hereby agree that flutter_braintree is great.',
                  displayName: 'Your Company',
                );
                final result = await Braintree.requestPaypalNonce(
                  tokenizationKey,
                  request,
                );
                if (result != null) {
                  showNonce(result);
                }
              },
              child: Text('PAYPAL VAULT FLOW'),
            ),
            ElevatedButton(
              onPressed: () async {
                final request = BraintreePayPalRequest(amount: '13.37');
                final result = await Braintree.requestPaypalNonce(
                  tokenizationKey,
                  request,
                );
                if (result != null) {
                  showNonce(result);
                }
              },
              child: Text('PAYPAL CHECKOUT FLOW'),
            ),
            ElevatedButton(
              onPressed: () async {
                final result = await Braintree.showCreditCardForm(
                  context,
                  authorization: tokenizationKey,
                  amount: '20.0',
                );
                if (result != null) {
                  showNonce(result);
                }
              },
              child: Text('SHOW CREDIT CARD DIALOG'),
            ),
          ],
        ),
      ),
    );
  }
}
