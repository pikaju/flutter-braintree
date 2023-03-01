import Flutter
import UIKit
import Braintree
import BraintreeDropIn

public class FlutterBraintreeCustomPlugin: BaseFlutterBraintreePlugin, FlutterPlugin, BTViewControllerPresentingDelegate, PKPaymentAuthorizationViewControllerDelegate {
	
	var flutterResult: FlutterResult?
	var deviceData: String?
	var applePayClient: BTApplePayClient?
	var client: BTAPIClient?
	var applePayNonce: BTApplePayCardNonce?

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
		flutterResult = result
		
		guard let authorization = getAuthorization(call: call) else {
			returnAuthorizationMissingError(result: result)
			isHandlingResult = false
			return
		}
		
		client = BTAPIClient(authorization: authorization)

		if call.method == "requestPaypalNonce" {
			let driver = BTPayPalDriver(apiClient: client!)
			
			guard let requestInfo = dict(for: "request", in: call) else {
				isHandlingResult = false
				return
			}
			
			collectDeviceData(client)

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
					self.handleResult(nonce: nonce, error: error, flutterResult: result)
					self.isHandlingResult = false
				}
			} else {
				collectDeviceData(client)

				let paypalRequest = BTPayPalVaultRequest()
				paypalRequest.displayName = requestInfo["displayName"] as? String
				paypalRequest.billingAgreementDescription = requestInfo["billingAgreementDescription"] as? String
				
				driver.tokenizePayPalAccount(with: paypalRequest) { (nonce, error) in
					self.handleResult(nonce: nonce, error: error, flutterResult: result)
					self.isHandlingResult = false
				}
			}
			
		} else if call.method == "tokenizeCreditCard" {
			collectDeviceData(client)

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
		} else if call.method == "collectDeviceData" {
			guard let apiClient = client else {
				return
			}
			let dataCollector = BTDataCollector(apiClient: apiClient)
			dataCollector.collectDeviceData { [weak self] (data: String) in
				self?.handleDeviceDataResult(deviceData: data, flutterResult: result)
				self?.isHandlingResult = false
			}
		}

		else if call.method == "isApplePayReady" {
			let enabled = PKPaymentAuthorizationViewController.canMakePayments()
			self.isHandlingResult = false
			result(enabled)
		}
		else if call.method == "applePayPayment" {
            collectDeviceData(client)

			guard let applePayRequest = dict(for: "request", in: call) else {return}

			self.setupPaymentRequest(applePayRequest) {(paymentRequest, error) in
				guard error == nil else {
					self.returnBraintreeError(result: result, error: error!)
					return
				}

				if let request = paymentRequest, let vc = PKPaymentAuthorizationViewController(paymentRequest: request) {
					vc.delegate = self
					
					UIApplication.shared.delegate?.window??.rootViewController?.present(vc, animated: true, completion: nil)
				} else {
					print("Error: Payment request is invalid.")
				}
			}
		}
		else {
			result(FlutterMethodNotImplemented)
			self.isHandlingResult = false
		}
	}
	
	func setupPaymentRequest(_ request: [String : Any], completion: @escaping (PKPaymentRequest?, Error?) -> Void) {
		guard let data = self.client else {
			return
		}
		
		let countryCode = request["countryCode"] as? String ?? ""
		let currencyCode = request["currencyCode"]  as? String ?? ""
		let merchantId = request["appleMerchantID"]  as? String ?? ""
		let amount = request["amount"] as? Double ?? 0.0

		applePayClient = BTApplePayClient(apiClient: data)
		applePayClient?.paymentRequest { (paymentRequest, error) in
			guard let paymentRequest = paymentRequest else {
				completion(nil, error)
				return
			}

			paymentRequest.countryCode = countryCode
			paymentRequest.currencyCode = currencyCode
			paymentRequest.merchantCapabilities = .capability3DS
			paymentRequest.merchantIdentifier = merchantId
			paymentRequest.paymentSummaryItems =
			[
				PKPaymentSummaryItem(label: "bluebet_deposit", amount: NSDecimalNumber(value: amount)),
			]
			paymentRequest.supportedNetworks = [.visa, .masterCard]
			paymentRequest.requiredBillingContactFields = [.postalAddress]

			completion(paymentRequest, nil)
		}
	}

	public func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController,
                         didAuthorizePayment payment: PKPayment,
                                  handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {

		// Tokenize the Apple Pay payment
		applePayClient?.tokenizeApplePay(payment) { (tokenizedApplePayPayment, error) in
			
			guard let tokenizedApplePayPayment = tokenizedApplePayPayment else {
				completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))

				return
			}
			
			self.applePayNonce = tokenizedApplePayPayment
			self.flutterResult?(self.buildApplePaymentNonceDict(nonce: self.applePayNonce, deviceData: self.deviceData))
			self.isHandlingResult = false

			UIApplication.shared.delegate?.window??.rootViewController?.dismiss(animated: true, completion: nil)
			completion(PKPaymentAuthorizationResult(status: .success, errors: nil))

		}
    }

	public func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
		guard let result = flutterResult else {
			flutterResult?(nil)
			return
		}

		self.isHandlingResult = false
		result(buildApplePaymentNonceDict(nonce: self.applePayNonce, deviceData: self.deviceData))
		UIApplication.shared.delegate?.window??.rootViewController?.dismiss(animated: true, completion: nil)
	}
	
	private func handleResult(nonce: BTPaymentMethodNonce?, error: Error?, flutterResult: FlutterResult) {
		if error != nil {
			returnBraintreeError(result: flutterResult, error: error!)
		} else if nonce == nil {
			flutterResult(nil)
		} else {
			flutterResult(buildPaymentNonceDict(nonce: nonce, deviceData: self.deviceData))
		}
	}
	
	public func paymentDriver(_ driver: Any, requestsPresentationOf viewController: UIViewController) {
		
	}
	
	public func paymentDriver(_ driver: Any, requestsDismissalOf viewController: UIViewController) {
		
	}
	
	public func collectDeviceData(_ client: BTAPIClient?) {
		guard let apiClient = client else {
			return
		}
		let dataCollector = BTDataCollector(apiClient: apiClient)
		//			dataCollector.setFraudMerchantID("")
		dataCollector.collectDeviceData { [weak self] (data: String) in
			print(data)
			self?.deviceData = data
		}
	}
	
	private func handleDeviceDataResult(deviceData: String?, flutterResult: FlutterResult) {
		if (deviceData != nil) {
			flutterResult(buildDeviceDataDict(deviceData: deviceData))
		} else {
			flutterResult(nil)
		}
	}
}
