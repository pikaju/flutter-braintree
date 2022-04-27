import Flutter
import UIKit
import Braintree
import BraintreeDropIn

public class FlutterBraintreeCustomPlugin: BaseFlutterBraintreePlugin, FlutterPlugin, BTViewControllerPresentingDelegate {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_braintree.custom", binaryMessenger: registrar.messenger())
        
        let instance = FlutterBraintreeCustomPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard !isHandlingResult else {
            returnAlreadyOpenError(result: result)
            return
        }
        
        isHandlingResult = true
        
        guard let authorization = getAuthorization(call: call) else {
            returnAuthorizationMissingError(result: result)
            isHandlingResult = false
            return
        }
        
        let client = BTAPIClient(authorization: authorization)
		let deviceData = collectDeviceData()

        if call.method == "requestPaypalNonce" {
            let driver = BTPayPalDriver(apiClient: client!)
            
			
            guard let requestInfo = dict(for: "request", in: call) else {
                isHandlingResult = false
                return
            }
            
            if let amount = requestInfo["amount"] as? String {
                let paypalRequest = BTPayPalCheckoutRequest(amount: amount)
                paypalRequest.currencyCode = requestInfo["currencyCode"] as? String
                paypalRequest.displayName = requestInfo["displayName"] as? String
                paypalRequest.billingAgreementDescription = requestInfo["billingAgreementDescription"] as? String
                if let intent = requestInfo["payPalPaymentIntent"] as? String {
                    switch intent {
                    case "order":
                        paypalRequest.intent = BTPayPalRequestIntent.order
                    case "sale":
                        paypalRequest.intent = BTPayPalRequestIntent.sale
                    default:
                        paypalRequest.intent = BTPayPalRequestIntent.authorize
                    }
                }
                if let userAction = requestInfo["payPalPaymentUserAction"] as? String {
                    switch userAction {
                    case "commit":
                        paypalRequest.userAction = BTPayPalRequestUserAction.commit
                    default:
                        paypalRequest.userAction = BTPayPalRequestUserAction.default
                    }
                }
                driver.tokenizePayPalAccount(with: paypalRequest) { (nonce, error) in
                    self.handleResult(nonce: nonce, deviceData: deviceData, error: error, flutterResult: result)
                    self.isHandlingResult = false
                }
            } else {
                let paypalRequest = BTPayPalVaultRequest()
                paypalRequest.displayName = requestInfo["displayName"] as? String
                paypalRequest.billingAgreementDescription = requestInfo["billingAgreementDescription"] as? String
                
                driver.tokenizePayPalAccount(with: paypalRequest) { (nonce, error) in
                    self.handleResult(nonce: nonce, deviceData: deviceData, error: error, flutterResult: result)
                    self.isHandlingResult = false
                }
            }
            
        } else if call.method == "tokenizeCreditCard" {
            let cardClient = BTCardClient(apiClient: client!)
            
            guard let cardRequestInfo = dict(for: "request", in: call) else {return}
            
            let card = BTCard()
            card.number = cardRequestInfo["cardNumber"] as? String
            card.expirationMonth = cardRequestInfo["expirationMonth"] as? String
            card.expirationYear = cardRequestInfo["expirationYear"] as? String
            card.cvv = cardRequestInfo["cvv"] as? String
            card.cardholderName = cardRequestInfo["cardholderName"] as? String
            
            cardClient.tokenizeCard(card) { (nonce, error) in
                self.handleResult(nonce: nonce, deviceData: deviceData, error: error, flutterResult: result)
                self.isHandlingResult = false
            }
        } else {
            result(FlutterMethodNotImplemented)
            self.isHandlingResult = false
        }
    }
    
	private func handleResult(nonce: BTPaymentMethodNonce?, deviceData: String?, error: Error?, flutterResult: FlutterResult) {
        if error != nil {
            returnBraintreeError(result: flutterResult, error: error!)
        } else if nonce == nil {
            flutterResult(nil)
        } else {
            flutterResult(buildPaymentNonceDict(nonce: nonce, deviceData: deviceData))
        }
    }
    
    public func paymentDriver(_ driver: Any, requestsPresentationOf viewController: UIViewController) {
        
    }
    
    public func paymentDriver(_ driver: Any, requestsDismissalOf viewController: UIViewController) {
        
    }
	
	public func collectDeviceData() -> String? {
		let deviceData = PPDataCollector.collectPayPalDeviceData()
		print("Send this device data to your server: \(deviceData)")
		return deviceData
	}
}
