import Flutter
import UIKit
import Braintree
import BraintreeDropIn
import PassKit

public class FlutterBraintreeDropInPlugin: BaseFlutterBraintreePlugin, FlutterPlugin, BTThreeDSecureRequestDelegate {
    

    
    private var completionBlock: FlutterResult!
    private var applePayInfo = [String : Any]()
    private var authorization: String!
    
    public func onLookupComplete(_ request: BTThreeDSecureRequest, lookupResult result: BTThreeDSecureResult, next: @escaping () -> Void) {
        next();
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_braintree.drop_in", binaryMessenger: registrar.messenger())
        
        let instance = FlutterBraintreeDropInPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        completionBlock = result
        
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

            var deviceData: String?
            if let collectDeviceData = bool(for: "collectDeviceData", in: call), collectDeviceData {
                deviceData = PPDataCollector.collectPayPalDeviceData()
            }
            
            if let vaultManagerEnabled = bool(for: "vaultManagerEnabled", in: call) {
                dropInRequest.vaultManager = vaultManagerEnabled
            }
            
            if let cardEnabled = bool(for: "cardEnabled", in: call) {
                dropInRequest.cardDisabled = !cardEnabled
            }
            
            if let paypalInfo = dict(for: "paypalRequest", in: call) {
                if let amount = paypalInfo["amount"] as? String {
                    let paypalRequest = BTPayPalCheckoutRequest(amount: amount)
                    paypalRequest.currencyCode = paypalInfo["currencyCode"] as? String
                    paypalRequest.displayName = paypalInfo["displayName"] as? String
                    paypalRequest.billingAgreementDescription = paypalInfo["billingAgreementDescription"] as? String
                    dropInRequest.payPalRequest = paypalRequest
                } else {
                    let paypalRequest = BTPayPalVaultRequest()
                    paypalRequest.displayName = paypalInfo["displayName"] as? String
                    paypalRequest.billingAgreementDescription = paypalInfo["billingAgreementDescription"] as? String
                    dropInRequest.payPalRequest = paypalRequest
                }
            } else {
                dropInRequest.paypalDisabled = true
            }
            
            if let applePayInfo = dict(for: "applePayRequest", in: call) {
                self.applePayInfo = applePayInfo
            } else {
                dropInRequest.applePayDisabled = true
            }
            
            guard let authorization = getAuthorization(call: call) else {
                returnAuthorizationMissingError(result: result)
                isHandlingResult = false
                return
            }
            
            self.authorization = authorization
            
            let dropInController = BTDropInController(authorization: authorization, request: dropInRequest) { (controller, braintreeResult, error) in
                controller.dismiss(animated: true, completion: nil)
                
                self.handleResult(result: braintreeResult, error: error, flutterResult: result, deviceData: deviceData)
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
    
    private func setupApplePay(flutterResult: FlutterResult) {
        let paymentRequest = PKPaymentRequest()
        paymentRequest.supportedNetworks = [.visa, .masterCard, .amex, .discover]
        paymentRequest.merchantCapabilities = .capability3DS
        let amount = applePayInfo["amount"] as! Double
        paymentRequest.paymentSummaryItems = [PKPaymentSummaryItem(label: applePayInfo["displayName"] as! String, amount: NSDecimalNumber(value: amount))]
        paymentRequest.countryCode = applePayInfo["countryCode"] as! String
        paymentRequest.currencyCode = applePayInfo["currencyCode"] as! String
        paymentRequest.merchantIdentifier = applePayInfo["appleMerchantID"] as! String
        
        guard let applePayController = PKPaymentAuthorizationViewController(paymentRequest: paymentRequest) else {
            return
        }
        
        applePayController.delegate = self
        
        UIApplication.shared.keyWindow?.rootViewController?.present(applePayController, animated: true, completion: nil)
    }
    
    private func handleResult(result: BTDropInResult?, error: Error?, flutterResult: FlutterResult, deviceData: String?) {
        if error != nil {
            returnBraintreeError(result: flutterResult, error: error!)
        } else if result?.isCanceled ?? false {
            flutterResult(nil)
        } else {
            if let result = result, result.paymentMethodType == .applePay {
                setupApplePay(flutterResult: flutterResult)
            } else {
                flutterResult(["paymentMethodNonce": buildPaymentNonceDict(nonce: result?.paymentMethod), "deviceData": deviceData])
            }
        }
    }
    
    private func handleApplePayResult(_ result: BTPaymentMethodNonce, flutterResult: FlutterResult) {
        flutterResult(["paymentMethodNonce": buildPaymentNonceDict(nonce: result)])
    }
}

// MARK: PKPaymentAuthorizationViewControllerDelegate
extension FlutterBraintreeDropInPlugin: PKPaymentAuthorizationViewControllerDelegate {
    public func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    @available(iOS 11.0, *)
    public func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        guard let apiClient = BTAPIClient(authorization: authorization) else { return }
        let applePayClient = BTApplePayClient(apiClient: apiClient)
        
        applePayClient.tokenizeApplePay(payment) { (tokenizedPaymentMethod, error) in
            guard let paymentMethod = tokenizedPaymentMethod, error == nil else {
                completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                return
            }
            
            print(paymentMethod.nonce)
            self.handleApplePayResult(paymentMethod, flutterResult: self.completionBlock)
            completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
        }
    }

    public func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, completion: @escaping (PKPaymentAuthorizationStatus) -> Void) {
        guard let apiClient = BTAPIClient(authorization: authorization) else { return }
        let applePayClient = BTApplePayClient(apiClient: apiClient)
        
        applePayClient.tokenizeApplePay(payment) { (tokenizedPaymentMethod, error) in
            guard let paymentMethod = tokenizedPaymentMethod, error == nil else {
                completion(.failure)
                return
            }
            
            print(paymentMethod.nonce)
            self.handleApplePayResult(paymentMethod, flutterResult: self.completionBlock)
            completion(.success)
        }
    }
}
