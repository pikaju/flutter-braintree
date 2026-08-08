# Braintree Flutter Plus

[![pub package](https://img.shields.io/pub/v/braintree_flutter_plus.svg)](https://pub.dev/packages/braintree_flutter_plus)
[![GitHub](https://img.shields.io/github/license/adlyyy4/flutter-braintree)](https://github.com/adlyyy4/flutter-braintree/blob/main/LICENSE)

An enhanced Flutter plugin that wraps the native [Braintree SDKs](https://www.braintreepayments.com/features/seamless-checkout/drop-in-ui) with the latest updates and improvements.
Unlike other plugins, this plugin not only lets you start Braintree's native Drop-in UI, but also allows you to create your own custom Flutter UI with Braintree functionality.

## 🔄 About This Fork

This is an **actively maintained fork** of the original `flutter_braintree` package by [pikaju](https://github.com/pikaju/flutter-braintree), which is no longer being maintained. We've taken over development to provide:

- 🛠️ **Critical bug fixes** and security updates
- 📱 **Modern platform support** (iOS 16+, Android 12+)
- 🔄 **Regular maintenance** and dependency updates
- 📦 **Published as `braintree_flutter_plus`** on pub.dev

> **Migration Note**: If you're using the original `flutter_braintree`, simply replace it with `braintree_flutter_plus` in your `pubspec.yaml` - the API remains the same!

## ✨ What's New in Plus

- **iOS Braintree SDK v7**: Fixes the Xcode 26 `-Wdeprecated-declarations` build failure; requires iOS 16+
- **Android Braintree SDK v5**: replaces the deprecated `drop-in` library (end-of-life 2027) with the direct v5 SDK; requires Android API 23+
- **Cross-platform Drop-in everywhere**: the native Drop-in SDKs (removed on both iOS and Android) are replaced by a single Flutter payment sheet on all platforms
- **Enhanced Stability**: Updated Cardinal SDK and core dependencies

## Installation

Add braintree_flutter_plus to your `pubspec.yaml` file:

```yaml
dependencies:
  ...
  braintree_flutter_plus: ^5.0.0
```

### Android

You must [migrate to AndroidX.](https://flutter.dev/docs/development/packages-and-plugins/androidx-compatibility)  
In `/app/build.gradle`, set your `minSdkVersion` to at least `23` (required by Braintree Android v5).

The plugin declares its own `FlutterBraintreeCustom` activity (for card / 3D Secure / PayPal), so no
manual activity declaration is required for card tokenization. The 3D Secure challenge activity is
provided automatically by the `three-d-secure` module.

#### PayPal (browser-switch return)

Braintree Android v5 returns from the PayPal web flow either via a verified
[Android App Link](https://developer.android.com/training/app-links) (recommended for production) or
via a custom deep-link scheme fallback (works in sandbox without a domain). Add the `intent-filter`(s)
you need to `FlutterBraintreeCustom` in your app's `AndroidManifest.xml` (inside `<application>`):

```xml
<activity android:name="com.example.flutter_braintree.FlutterBraintreeCustom">
    <!-- Deep-link fallback: <your.package.id-without-underscores>.braintree -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="com.your.app.braintree" />
    </intent-filter>
    <!-- App Link (production) -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" android:host="your-domain.com" android:pathPrefix="/braintree-payments" />
    </intent-filter>
</activity>
```

- **Sandbox/testing (no domain):** just add the **deep-link** `intent-filter`. The plugin auto-derives
  the scheme from your package id (underscores removed) + `.braintree`, so no extra config is needed.
- **Production:** additionally register your domain in the Braintree Control Panel, host
  `/.well-known/assetlinks.json`, add the **App Link** `intent-filter`, and pass
  `BraintreePayPalRequest.appLinkReturnUrl`. See
  [APP_LINK_SETUP.md](https://github.com/braintree/braintree_android/blob/main/APP_LINK_SETUP.md).

> Card tokenization and 3D Secure do **not** require any of this — only PayPal.
> Venmo and Google Pay are not currently supported by the Android v5 integration.

### iOS

You may need to add or uncomment the following line at the top of your `ios/Podfile`:

```ruby
platform :ios, '16.0'
```

Braintree v7 requires a minimum deployment target of **iOS 16.0**.

#### PayPal / Venmo / 3D Secure

In your App Delegate or your Runner project, you need to specify the URL scheme for redirecting payments as following:

```swift
BTAppContextSwitcher.setReturnURLScheme("com.your-company.your-app.payments")
```

Moreover, you need to specify the same URL scheme in your `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.your-company.your-app.payments</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.your-company.your-app.payments</string>
        </array>
    </dict>
</array>
```

See the official [Braintree documentation](https://developers.braintreepayments.com/guides/paypal/client-side/ios/v4) for a more detailed explanation.

## Usage

You must first create a [Braintree account](https://www.braintreepayments.com/). In your control panel you can create a tokenization key. You likely also want to set up a backend server. Make sure to read the [Braintree developer documentation](https://developers.braintreepayments.com/) so you understand all key concepts.

In your code, import the plugin:

```dart
import 'package:flutter_braintree/flutter_braintree.dart';
```

You can then create your own user interface using Flutter or use Braintree's drop-in UI.

### Flutter UI

#### Credit cards

Create a credit card request object:

```dart
final request = BraintreeCreditCardRequest(
  cardNumber: '4111111111111111',
  expirationMonth: '12',
  expirationYear: '2021',
  cvv: '367'
);
```

Then ask Braintree to tokenize it:

```dart
BraintreePaymentMethodNonce result = await Braintree.tokenizeCreditCard(
   '<Insert your tokenization key or client token here>',
   request,
);
print(result.nonce);
```

#### PayPal

Create a PayPal request object:

```dart
final request = BraintreePayPalRequest(amount: '13.37');
```

Or, for the Vault flow:

```dart
final request = BraintreePayPalRequest(
  billingAgreementDescription: 'I hereby agree that flutter_braintree is great.',
);
```

Then launch the PayPal request:

```dart
BraintreePaymentMethodNonce result = await Braintree.requestPaypalNonce(
   '<Insert your tokenization key or client token here>',
   request,
);
if (result != null) {
  print('Nonce: ${result.nonce}');
} else {
  print('PayPal flow was canceled.');
}
```

### Braintree's native drop-in

Create a drop-in request object:

```dart
final request = BraintreeDropInRequest(
  clientToken: '<Insert your client token here>',
  collectDeviceData: true,
  googlePaymentRequest: BraintreeGooglePaymentRequest(
    totalPrice: '4.20',
    currencyCode: 'USD',
    billingAddressRequired: false,
  ),
  paypalRequest: BraintreePayPalRequest(
    amount: '4.20',
    displayName: 'Example company',
  ),
);
```

Then launch the drop-in (a `BuildContext` is required as of v6.0.0):

```dart
BraintreeDropInResult? result = await BraintreeDropIn.start(context, request);
```

> As of v6.0.0 this presents a cross-platform Flutter payment sheet on **all** platforms (the native
> Drop-in SDKs have been removed: iOS has no v7 release and the Android Drop-in is deprecated). The
> sheet drives the direct Braintree SDKs (iOS v7, Android v5).

Access the payment nonce:

```dart
if (result != null) {
  print('Nonce: ${result.paymentMethodNonce.nonce}');
} else {
  print('Selection was canceled.');
}
```

To increase the chances of success with 3DS2 challenge is possible to add additional information about the user
as mentioned in the guide to [Migrate to 3D Secure 2](https://developer.paypal.com/braintree/docs/guides/3d-secure/migration).

```dart
var request = BraintreeDropInRequest(
  clientToken: '<Insert your client token here>',
  collectDeviceData: true,
  requestThreeDSecureVerification: true,
  email: "test@email.com",
  amount: "0,01",
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
  cardEnabled: true,
);
```

See `BraintreeDropInRequest` and `BraintreeDropInResult` for more documentation.
