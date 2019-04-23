# Braintree for Flutter

A Flutter plugin that wraps the native
[Braintree Drop-In UI SDKs](https://www.braintreepayments.com/features/seamless-checkout/drop-in-ui).
Currently only supports Android.

## Installation

Add braintree to your `pubspec.yaml` file:
```yaml
dependencies:
  ...
  braintree: ^0.0.2
```

### Android

In `/app/build.gradle`, set your `minSdkVersion` to at least `21`.

#### PayPal

In order for your Drop-in to support PayPal payments, you must allow for PayPal's
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

## Usage

Import the plugin:
```dart
import 'package:braintree/braintree.dart';
```

Then launch the Drop-in UI:
```dart
BraintreeDropInResult result = await BraintreeDropIn.launch(
  clientToken: '<INSERT YOUR CLIENT TOKEN HERE>',
  collectDeviceData: false,
);
```

Access the payment nonce:

```dart
if (result != null) {
  print('Nonce: ${result.paymentMethodNonce.nonce}');
} else {
  print('Payment was canceled.');
}
```

See `BraintreeDropInResult` and `BraintreePaymentMethodNonce` for more documentation.

