import Flutter
import UIKit
import Braintree
import BraintreeDropIn
import PassKit

public class FlutterBraintreeCustomPlugin: BaseFlutterBraintreePlugin, FlutterPlugin, BTViewControllerPresentingDelegate {

    private var currentFlutterResult: FlutterResult?
    private var currentAuthorization: String?

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

        currentAuthorization = authorization
        let client = BTAPIClient(authorization: authorization)

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
                paypalRequest.isShippingAddressRequired = requestInfo["isShippingAddressRequired"] != nil ? requestInfo["isShippingAddressRequired"]! as! Bool : false
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
                    self.handleResult(nonce: nonce, error: error, flutterResult: result)
                    self.isHandlingResult = false
                }
            } else {
                let paypalRequest = BTPayPalVaultRequest()
                paypalRequest.displayName = requestInfo["displayName"] as? String
                paypalRequest.billingAgreementDescription = requestInfo["billingAgreementDescription"] as? String
                paypalRequest.isShippingAddressRequired = requestInfo["isShippingAddressRequired"] != nil ? requestInfo["isShippingAddressRequired"]! as! Bool : false

                driver.tokenizePayPalAccount(with: paypalRequest) { (nonce, error) in
                    self.handleResult(nonce: nonce, error: error, flutterResult: result)
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
                self.handleResult(nonce: nonce, error: error, flutterResult: result)
                self.isHandlingResult = false
            }
        } else if call.method == "requestApplePayNonce" {
            guard let requestInfo = dict(for: "request", in: call) else {
                isHandlingResult = false
                return
            }

            let merchantIdentifier = requestInfo["merchantIdentifier"] as? String ?? ""

            // Get supported networks from request
            var supportedNetworks: [PKPaymentNetwork] = []
            if let networks = requestInfo["supportedNetworks"] as? [Int] {
                supportedNetworks = networks.compactMap { network in
                    switch network {
                    case 0: return PKPaymentNetwork.visa
                    case 1: return PKPaymentNetwork.masterCard
                    case 2: return PKPaymentNetwork.amex
                    case 3: return PKPaymentNetwork.discover
                    default: return nil
                    }
                }
            }

            // Check if Apple Pay is available for this merchant
            let canMakePayments = PKPaymentAuthorizationController.canMakePayments()
            let canMakePaymentsWithMerchant = PKPaymentAuthorizationController.canMakePayments(usingNetworks: supportedNetworks)

            if !canMakePayments {
                result(FlutterError(code: "APPLE_PAY_ERROR",
                                  message: "Apple Pay is not available on this device. Please check if Apple Pay is set up in your device settings.",
                                  details: nil))
                isHandlingResult = false
                return
            }

            if !canMakePaymentsWithMerchant {
                result(FlutterError(code: "APPLE_PAY_ERROR",
                                  message: "Apple Pay is not available for merchant: \(merchantIdentifier). Please check your Apple Pay configuration in Xcode and Apple Developer account.",
                                  details: nil))
                isHandlingResult = false
                return
            }

            let paymentRequest = PKPaymentRequest()
            paymentRequest.merchantIdentifier = merchantIdentifier
            paymentRequest.countryCode = requestInfo["countryCode"] as? String ?? "US"
            paymentRequest.currencyCode = requestInfo["currencyCode"] as? String ?? "USD"
            paymentRequest.supportedNetworks = supportedNetworks

            if let paymentSummaryItems = requestInfo["paymentSummaryItems"] as? [[String: Any]] {
                paymentRequest.paymentSummaryItems = paymentSummaryItems.compactMap { item in
                    guard let label = item["label"] as? String,
                          let amount = item["amount"] as? Double,
                          let typeRaw = item["type"] as? Int else {
                        return nil
                    }

                    let _: PKPaymentSummaryItemType = typeRaw == 0 ? .final : .pending
                    return PKPaymentSummaryItem(label: label, amount: NSDecimalNumber(value: amount))
                }
            }

            // Check if the merchant identifier is valid
            guard !paymentRequest.merchantIdentifier.isEmpty else {
                result(FlutterError(code: "APPLE_PAY_ERROR",
                                  message: "Merchant identifier is required",
                                  details: nil))
                isHandlingResult = false
                return
            }

            // Check if we have payment summary items
            guard !paymentRequest.paymentSummaryItems.isEmpty else {
                result(FlutterError(code: "APPLE_PAY_ERROR",
                                  message: "At least one payment summary item is required",
                                  details: nil))
                isHandlingResult = false
                return
            }

            // Add merchant capabilities
            paymentRequest.merchantCapabilities = .capability3DS

            // Try to initialize the controller
            guard let applePayController = PKPaymentAuthorizationViewController(paymentRequest: paymentRequest) else {
                result(FlutterError(code: "APPLE_PAY_ERROR",
                                  message: "Failed to initialize Apple Pay.",
                                  details: nil))
                isHandlingResult = false
                return
            }

            // Set the delegate
            applePayController.delegate = self

            // Present the controller
            if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
                rootViewController.present(applePayController, animated: true) {
                    print("Apple Pay sheet presented successfully")
                }
                self.currentFlutterResult = result
            } else {
                result(FlutterError(code: "APPLE_PAY_ERROR",
                                  message: "No root view controller found to present Apple Pay",
                                  details: nil))
                isHandlingResult = false
            }
        } else if call.method == "requestGooglePayNonce" {
            // Google Pay is not available on iOS
            result(FlutterError(code: "GOOGLE_PAY_ERROR",
                              message: "Google Pay is not available on iOS devices",
                              details: nil))
            isHandlingResult = false
        } else {
            result(FlutterMethodNotImplemented)
            self.isHandlingResult = false
        }
    }

    private func handleResult(nonce: BTPaymentMethodNonce?, error: Error?, flutterResult: FlutterResult) {
        if error != nil {
            returnBraintreeError(result: flutterResult, error: error!)
        } else if nonce == nil {
            flutterResult(nil)
        } else {
            flutterResult(buildPaymentNonceDict(nonce: nonce));
        }
    }
    
    public func paymentDriver(_ driver: Any, requestsPresentationOf viewController: UIViewController) {
        
    }
    
    public func paymentDriver(_ driver: Any, requestsDismissalOf viewController: UIViewController) {
        
    }
}

extension FlutterBraintreeCustomPlugin: PKPaymentAuthorizationViewControllerDelegate {
    public func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        guard let authorization = currentAuthorization,
              let client = BTAPIClient(authorization: authorization) else {
            completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
            return
        }

        let applePayClient = BTApplePayClient(apiClient: client)
        applePayClient.tokenizeApplePay(payment) { (nonce, error) in
            if let error = error {
                completion(PKPaymentAuthorizationResult(status: .failure, errors: [error]))
                return
            }

            if let nonce = nonce {
                self.handleResult(nonce: nonce, error: nil, flutterResult: self.currentFlutterResult!)
                completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
            } else {
                completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
            }
        }
    }

    public func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        controller.dismiss(animated: true) {
            if self.currentFlutterResult != nil {
                self.currentFlutterResult!(nil)
                self.currentFlutterResult = nil
            }
            self.isHandlingResult = false
        }
    }
}