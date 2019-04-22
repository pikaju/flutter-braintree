# Braintree for Flutter

A Flutter plugin that wraps the native Braintree Drop-In UI SDKs.
Currently only supports Android.

## Installation

Add braintree to your `pubspec.yaml` file:
```yaml
dependencies:
  ...
  braintree: ^0.0.1
```

### Android

In order for your Drop-in to support PayPal payments, you must allow for PayPal's
browser switch by adding an intent filter to your AndroidManifest.xml:
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

**Make sure the scheme contains only lowercase letters, and ends with `.braintree`.
If your package contains underscores, remove them from the specified scheme!**

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

