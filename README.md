# Braintree for Flutter

A Flutter plugin that wraps the native [Braintree SDKs](https://www.braintreepayments.com/features/seamless-checkout/drop-in-ui).
Unlike other plugins, this plugin not only lets you start Braintree's native Drop-in UI, but also allows you to create your own custom Flutter UI with Braintree functionality.

## Installation

Add flutter_braintree to your `pubspec.yaml` file:
```yaml
dependencies:
  ...
  flutter_braintree: <version>
```

### Android

You must [migrate to AndroidX.](https://flutter.dev/docs/development/packages-and-plugins/androidx-compatibility)  
In `/app/build.gradle`, set your `minSdkVersion` to at least `21`.

#### Card.io

[Card.io](https://github.com/card-io) enables credit card scanning so as to remove the need to type in credit card details manually.
This feature became optional in `flutter_braintree` version `0.6.0` to potentially reduce app sizes.
To enable it for the Braintree Drop-in UI, add the following line to your `app` level `build.gradle` file:
```gradle
dependencies {
    ...
    implementation 'io.card:android-sdk:5.+'
}
```

#### PayPal / Venmo / 3D Secure

In order for this plugin to support PayPal, Venmo or 3D Secure payments, you must allow for the
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

Add the wallet enabled meta-data tag to your `AndroidManifest.xml` (inside the `<application>` body):
```xml
<meta-data android:name="com.google.android.gms.wallet.api.enabled" android:value="true"/>
```

### iOS

**Warning:** Device data collection is not yet supported for iOS.

#### PayPal / Venmo / 3D Secure

In your App Delegate or your Runner project, you need to specify the URL scheme for redirecting payments as following:
```swift 
BTAppSwitch.setReturnURLScheme("com.your-company.your-app.braintree")
```

Moreover, you need to specify the same URL scheme in your `Info.plist`: 
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.your-company.your-app.braintree</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.your-company.your-app.braintree</string>
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

Then launch the drop-in:
```dart
BraintreeDropInResult result = await BraintreeDropIn.start(request);
```

Access the payment nonce:
```dart
if (result != null) {
  print('Nonce: ${result.paymentMethodNonce.nonce}');
} else {
  print('Selection was canceled.');
}
```

See `BraintreeDropInRequest` and `BraintreeDropInResult` for more documentation.

