import UIKit
import Flutter
// The umbrella `Braintree` module is only available via CocoaPods. Under Swift
// Package Manager the app target would need braintree_ios added as a direct
// dependency, so the optional app-switch handler below is compiled only when the
// module is importable.
#if canImport(Braintree)
import Braintree
#endif

@main
@objc class AppDelegate: FlutterAppDelegate {

    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
      GeneratedPluginRegistrant.register(with: self)
      // In Braintree v7 the return URL scheme is configured via the app's URL Types
      // in Info.plist; BTAppContextSwitcher no longer exposes a returnURLScheme setter.
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    #if canImport(Braintree)
    // Handles PayPal app-switch return URLs. Only needed for the app-switch flow;
    // the standard ASWebAuthenticationSession web flow handles its own callback.
    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.scheme == "com.example.flutterBraintreeExample.payments" {
            return BTAppContextSwitcher.sharedInstance.handleOpen(url)
        }

        return super.application(app, open: url, options: options)
    }
    #endif

}
