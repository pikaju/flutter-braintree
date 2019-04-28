# Braintree for Flutter

A Flutter plugin that wraps the native
[Braintree Drop-In UI SDKs](https://www.braintreepayments.com/features/seamless-checkout/drop-in-ui).
Currently only supports Android.

## Installation

Add braintree to your `pubspec.yaml` file:
```yaml
dependencies:
  ...
  braintree: ^0.1.1
```

### Android

As of version `0.1.0`, you must [migrate to AndroidX.](https://flutter.dev/docs/development/packages-and-plugins/androidx-compatibility)  
In `/app/build.gradle`, set your `minSdkVersion` to at least `21`.

#### PayPal / Venmo

In order for your Drop-in to support PayPal or Venmo payments, you must allow for the
browser switch by adding an intent filter to your `AndroidManifest.xml` (inside the `<application>` body):
```xml
<activity android:name="com.braintreepayments.api.BraintreeBrowserSwitchActivity"
    android:launchMode="singleTask">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="${applicationId}.braintree" />
    </intent-filter>
</activity>
```

**Important:** Your app's URL scheme must begin with your app's package ID and end with `.braintree`. For example, if the Package ID is `com.your-company.your-app`, then your URL scheme should be `com.your-company.your-app.braintree`. `${applicationId}` is automatically applied with your app's package when using Gradle.
**Note:** The scheme you define must use all lowercase letters. If your package contains underscores, the underscores should be removed when specifying the scheme in your Android Manifest.

#### Google Pay

Add the walled enabled meta-data tag to your `AndroidManifest.xml`:
```xml
<meta-data android:name="com.google.android.gms.wallet.api.enabled" android:value="true"/>
```
**Warning:** There may be issues with Google Pay, I am working on fixing them as soon as possible.

## Usage

Import the plugin:
```dart
import 'package:braintree/braintree.dart';
```

Create a drop-in request object:
```dart
var request = BraintreeDropInRequest(
  clientToken: '<Insert your client token here>'
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

Then launch the drop-in:
```dart
BraintreeDropInResult result = await BraintreeDropIn.start(request);
```

Access the payment nonce:
```dart
if (result != null) {
  print('Nonce: ${result.paymentMethodNonce.nonce}');
} else {
  print('Payment was canceled.');
}
```

See `BraintreeDropInRequest` and `BraintreeDropInResult` for more documentation.

