import Flutter
import UIKit
import Braintree
import BraintreeDropIn

public class SwiftFlutterBraintreePlugin: NSObject, FlutterPlugin {
    
    var isHandlingResult: Bool = false
    
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_braintree.drop_in", binaryMessenger: registrar.messenger())
        
        let instance = SwiftFlutterBraintreePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        BTAppSwitch.setReturnURLScheme("com.example.flutterBraintreeExample.payments")
    }

    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "start" {
            guard !isHandlingResult else { result(FlutterError(code: "drop_in_already_running", message: "Cannot launch another Drop-in activity while one is already running.", details: nil)); return }
            
            isHandlingResult = true
            
            let dropInRequest = BTDropInRequest()
            
            if let amount = string(for: "amount", in: call) {
                dropInRequest.threeDSecureRequest?.amount = NSDecimalNumber(string: amount)
            }
            
            if let requestThreeDSecureVerification = bool(for: "requestThreeDSecureVerification", in: call) {
                dropInRequest.threeDSecureVerification = requestThreeDSecureVerification
            }
            
            if let vaultManagerEnabled = bool(for: "vaultManagerEnabled", in: call) {
                dropInRequest.vaultManager = vaultManagerEnabled
            }

            let clientToken = string(for: "clientToken", in: call)
            let tokenizationKey = string(for: "tokenizationKey", in: call)
            
            guard let authorization = clientToken ?? tokenizationKey else {
                result(FlutterError(code: "braintree_error", message: "Authorization not specified (no clientToken or tokenizationKey)", details: nil))
                isHandlingResult = false
                return
            }
            
            let dropInController = BTDropInController(authorization: authorization, request: dropInRequest) { (controller, braintreeResult, error) in
                controller.dismiss(animated: true, completion: nil)
                
                self.handle(braintreeResult: braintreeResult, error: error, flutterResult: result)
                self.isHandlingResult = false
            }
            
            guard let existingDropInController = dropInController else {
                result(FlutterError(code: "braintree_error", message: "BTDropInController not initialized (no API key or request specified?)", details: nil))
                isHandlingResult = false
                return
            }
                
            UIApplication.shared.keyWindow?.rootViewController?.present(existingDropInController, animated: true, completion: nil)
        }
        else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    
    private func handle(braintreeResult: BTDropInResult?, error: Error?, flutterResult: FlutterResult) {
        if error != nil {
            flutterResult(FlutterError(code: "braintree_error", message: error?.localizedDescription, details: nil))
        }
        else if braintreeResult?.isCancelled ?? false {
            flutterResult(nil)
        }
        else if let braintreeResult = braintreeResult {
            let nonceResultDict: [String: Any?] = ["nonce": braintreeResult.paymentMethod?.nonce,
                                                   "typeLabel": braintreeResult.paymentMethod?.type,
                                                   "description": braintreeResult.paymentMethod?.localizedDescription,
                                                   "isDefault": braintreeResult.paymentMethod?.isDefault]
            
            let resultDict: [String: Any?] = ["paymentMethodNonce": nonceResultDict]
            
            flutterResult(resultDict)
        }
    }
    

    private func string(for key: String, in call: FlutterMethodCall) -> String? {
        return (call.arguments as? [String: Any])?[key] as? String
    }
    
    
    private func bool(for key: String, in call: FlutterMethodCall) -> Bool? {
        return (call.arguments as? [String: Any])?[key] as? Bool
    }
    
}
