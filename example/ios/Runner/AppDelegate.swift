import UIKit
import Flutter
import Braintree

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    
    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
      GeneratedPluginRegistrant.register(with: self)
        BTAppContextSwitcher.setReturnURLScheme("com.example.flutterBraintreeExample.payments")
      
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    
    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.scheme == "com.example.flutterBraintreeExample.payments" {
            return BTAppContextSwitcher.handleOpenURL(url)
        }
        
        return super.application(app, open: url, options:  options);
    }

}
