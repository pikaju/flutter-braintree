import Flutter
import UIKit
import Braintree
import BraintreeDropIn

public class FlutterBraintreeDropInPlugin: BaseFlutterBraintreePlugin, FlutterPlugin, BTThreeDSecureRequestDelegate {
    
    public func onLookupComplete(_ request: BTThreeDSecureRequest, result: BTThreeDSecureLookup, next: @escaping () -> Void) {
        next();
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_braintree.drop_in", binaryMessenger: registrar.messenger())
        
        let instance = FlutterBraintreeDropInPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "start" {
            guard !isHandlingResult else {
                returnAlreadyOpenError(result: result)
                return
            }
            
            isHandlingResult = true
            
            let dropInRequest = BTDropInRequest()
            
            if let amount = string(for: "amount", in: call) {
                let threeDSecureRequest = BTThreeDSecureRequest()
                threeDSecureRequest.threeDSecureRequestDelegate = self
                threeDSecureRequest.amount = NSDecimalNumber(string: amount)
                dropInRequest.threeDSecureRequest = threeDSecureRequest
            }
            
            if let requestThreeDSecureVerification = bool(for: "requestThreeDSecureVerification", in: call) {
                dropInRequest.threeDSecureVerification = requestThreeDSecureVerification
            }
            
            if let vaultManagerEnabled = bool(for: "vaultManagerEnabled", in: call) {
                dropInRequest.vaultManager = vaultManagerEnabled
            }
            
            if let cardEnabled = bool(for: "cardEnabled", in: call) {
                dropInRequest.cardDisabled = !cardEnabled
            }
            
            if let paypalInfo = dict(for: "paypalRequest", in: call) {
                let amount = paypalInfo["amount"] as? String;
                
                let paypalRequest = amount != nil ? BTPayPalRequest(amount: amount!) : BTPayPalRequest();
                paypalRequest.currencyCode = paypalInfo["currencyCode"] as? String;
                paypalRequest.displayName = paypalInfo["displayName"] as? String;
                paypalRequest.billingAgreementDescription = paypalInfo["billingAgreementDescription"] as? String;
                dropInRequest.payPalRequest = paypalRequest
            } else {
                dropInRequest.paypalDisabled = true
            }
            
            guard let authorization = getAuthorization(call: call) else {
                returnAuthorizationMissingError(result: result)
                isHandlingResult = false
                return
            }
            
            let dropInController = BTDropInController(authorization: authorization, request: dropInRequest) { (controller, braintreeResult, error) in
                controller.dismiss(animated: true, completion: nil)
                
                self.handleResult(result: braintreeResult, error: error, flutterResult: result)
                self.isHandlingResult = false
            }
            
            guard let existingDropInController = dropInController else {
                result(FlutterError(code: "braintree_error", message: "BTDropInController not initialized (no API key or request specified?)", details: nil))
                isHandlingResult = false
                return
            }
                
            UIApplication.shared.keyWindow?.rootViewController?.present(existingDropInController, animated: true, completion: nil)
        }
    }
    
    private func handleResult(result: BTDropInResult?, error: Error?, flutterResult: FlutterResult) {
        if error != nil {
            returnBraintreeError(result: flutterResult, error: error!)
        } else if result?.isCancelled ?? false {
            flutterResult(nil)
        } else {
            flutterResult(["paymentMethodNonce": buildPaymentNonceDict(nonce: result?.paymentMethod)])
        }
    }
}
