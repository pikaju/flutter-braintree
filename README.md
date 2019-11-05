# Braintree for Flutter

A Flutter plugin that wraps the native
[Braintree Drop-In UI SDKs](https://www.braintreepayments.com/features/seamless-checkout/drop-in-ui).
Currently only supports Android.

## Installation

Add flutter_braintree to your `pubspec.yaml` file:
```yaml
dependencies:
  ...
  flutter_braintree: ^0.2.0
```

### Android

You must [migrate to AndroidX.](https://flutter.dev/docs/development/packages-and-plugins/androidx-compatibility)  
In `/app/build.gradle`, set your `minSdkVersion` to at least `21`.

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

In your App Delegate or your Runner project, you need to specify the URL scheme for redirecting payments as following:

```swift 
BTAppSwitch.setReturnURLScheme("com.your-company.your-app.braintree")
```
Moreover, you need to specify the same URL scheme in your Info.plist: 

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

## Usage

Import the plugin:
```dart
import 'package:flutter_braintree/flutter_braintree.dart';
```

Create a drop-in request object:
```dart
var request = BraintreeDropInRequest(
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

