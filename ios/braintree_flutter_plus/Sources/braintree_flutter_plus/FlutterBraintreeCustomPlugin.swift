import Flutter
import UIKit
import PassKit
// CocoaPods exposes a single umbrella `Braintree` module, whereas Swift Package
// Manager exposes the individual modules. Import whichever is available.
#if canImport(Braintree)
import Braintree
#else
import BraintreeCore
import BraintreeCard
import BraintreePayPal
import BraintreeApplePay
import BraintreeDataCollector
import BraintreeThreeDSecure
#endif

func makePaymentSummaryItems(from info: [String: Any]) -> [PKPaymentSummaryItem]? {
    guard let paymentSummaryItems = info["paymentSummaryItems"] as? [[String: Any]] else {
        return nil
    }

    var outList: [PKPaymentSummaryItem] = []
    for paymentSummaryItem in paymentSummaryItems {
        guard let label = paymentSummaryItem["label"] as? String,
              let amount = paymentSummaryItem["amount"] as? Double,
              let type = paymentSummaryItem["type"] as? UInt,
              let pkType = PKPaymentSummaryItemType(rawValue: type) else {
            return nil
        }
        outList.append(PKPaymentSummaryItem(label: label, amount: NSDecimalNumber(value: amount), type: pkType))
    }

    return outList
}

public class FlutterBraintreeCustomPlugin: BaseFlutterBraintreePlugin, FlutterPlugin {
    // Apple Pay is presented natively and resolved through the delegate callbacks below.
    private var applePayResult: FlutterResult?
    private var applePayAuthorization: String?
    private var applePayDeviceData: String?
    private var applePayNonceReturned = false

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

        switch call.method {
        case "requestPaypalNonce":
            handlePayPal(authorization: authorization, call: call, result: result)
        case "tokenizeCreditCard":
            handleTokenizeCreditCard(authorization: authorization, call: call, result: result)
        case "requestApplePayNonce":
            handleApplePay(authorization: authorization, call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
            isHandlingResult = false
        }
    }

    // MARK: - PayPal

    private func handlePayPal(authorization: String, call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let requestInfo = dict(for: "request", in: call) else {
            isHandlingResult = false
            result(nil)
            return
        }

        let payPalClient = BTPayPalClient(authorization: authorization)
        let amount = requestInfo["amount"] as? String

        let completion: (BTPayPalAccountNonce?, Error?) -> Void = { [weak self] nonce, error in
            self?.finish(nonce: nonce, error: error, authorization: authorization, call: call, amount: amount, result: result)
        }

        if let amount = amount {
            // v7 request properties are immutable, so everything is passed to the initializer.
            let intent: BTPayPalRequestIntent
            switch requestInfo["payPalPaymentIntent"] as? String {
            case "order":
                intent = .order
            case "sale":
                intent = .sale
            default:
                intent = .authorize
            }
            let userAction: BTPayPalRequestUserAction =
                (requestInfo["payPalPaymentUserAction"] as? String) == "commit" ? .payNow : .none
            let request = BTPayPalCheckoutRequest(
                amount: amount,
                intent: intent,
                userAction: userAction,
                billingAgreementDescription: requestInfo["billingAgreementDescription"] as? String,
                currencyCode: requestInfo["currencyCode"] as? String,
                displayName: requestInfo["displayName"] as? String
            )
            payPalClient.tokenize(request, completion: completion)
        } else {
            let request = BTPayPalVaultRequest(
                billingAgreementDescription: requestInfo["billingAgreementDescription"] as? String,
                displayName: requestInfo["displayName"] as? String
            )
            payPalClient.tokenize(request, completion: completion)
        }
    }

    // MARK: - Credit card (with optional 3D Secure)

    private func handleTokenizeCreditCard(authorization: String, call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let requestInfo = dict(for: "request", in: call) else {
            isHandlingResult = false
            result(nil)
            return
        }

        let cardClient = BTCardClient(authorization: authorization)
        let amount = requestInfo["amount"] as? String

        // BTCard is immutable in v7 — all fields must be supplied to the initializer.
        let card = BTCard(
            number: requestInfo["cardNumber"] as? String ?? "",
            expirationMonth: requestInfo["expirationMonth"] as? String ?? "",
            expirationYear: requestInfo["expirationYear"] as? String ?? "",
            cvv: requestInfo["cvv"] as? String ?? "",
            cardholderName: requestInfo["cardholderName"] as? String
        )

        cardClient.tokenize(card) { [weak self] nonce, error in
            guard let self = self else { return }

            if let error = error {
                self.finish(nonce: nil, error: error, authorization: authorization, call: call, amount: amount, result: result)
                return
            }
            guard let nonce = nonce else {
                self.isHandlingResult = false
                result(nil)
                return
            }

            let requires3DS = self.bool(for: "requestThreeDSecureVerification", in: call) ?? false
            if requires3DS, let amount = amount {
                self.performThreeDSecure(authorization: authorization, nonce: nonce.nonce, amount: amount, call: call) { verifiedNonce, threeDError in
                    if let threeDError = threeDError {
                        self.finish(nonce: nil, error: threeDError, authorization: authorization, call: call, amount: amount, result: result)
                    } else {
                        self.finish(nonce: verifiedNonce ?? nonce, error: nil, authorization: authorization, call: call, amount: amount, result: result)
                    }
                }
            } else {
                self.finish(nonce: nonce, error: nil, authorization: authorization, call: call, amount: amount, result: result)
            }
        }
    }

    private func performThreeDSecure(authorization: String, nonce: String, amount: String, call: FlutterMethodCall, completion: @escaping (BTPaymentMethodNonce?, Error?) -> Void) {
        let billing = dict(for: "billingAddress", in: call)
        let address = BTThreeDSecurePostalAddress(
            givenName: billing?["givenName"] as? String,
            surname: billing?["surname"] as? String,
            streetAddress: billing?["streetAddress"] as? String,
            extendedAddress: billing?["extendedAddress"] as? String,
            locality: billing?["locality"] as? String,
            region: billing?["region"] as? String,
            postalCode: billing?["postalCode"] as? String,
            countryCodeAlpha2: billing?["countryCodeAlpha2"] as? String,
            phoneNumber: billing?["phoneNumber"] as? String
        )

        let additionalInformation = BTThreeDSecureAdditionalInformation(shippingAddress: address)
        let request = BTThreeDSecureRequest(
            amount: amount,
            nonce: nonce,
            additionalInformation: additionalInformation,
            billingAddress: address,
            email: string(for: "email", in: call)
        )

        // braintree_ios 7.x requires a non-nil threeDSecureRequestDelegate when
        // versionRequested is 2 (the default), otherwise BTThreeDSecureClient.start
        // throws a configuration error before the flow runs. We provide a
        // pass-through delegate that immediately continues the flow.
        request.threeDSecureRequestDelegate = self

        let threeDSecureClient = BTThreeDSecureClient(authorization: authorization)
        threeDSecureClient.start(request) { threeDResult, error in
            if let error = error {
                completion(nil, error)
            } else {
                completion(threeDResult?.tokenizedCard, nil)
            }
        }
    }

    // MARK: - Apple Pay

    private func handleApplePay(authorization: String, call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let info = dict(for: "request", in: call) else {
            isHandlingResult = false
            result(nil)
            return
        }

        let paymentRequest = PKPaymentRequest()
        if let supportedNetworks = info["supportedNetworks"] as? [Int] {
            paymentRequest.supportedNetworks = supportedNetworks.compactMap { PKPaymentNetwork.mapRequestedNetwork(rawValue: $0) }
        }
        paymentRequest.merchantCapabilities = .capability3DS
        paymentRequest.countryCode = info["countryCode"] as? String ?? ""
        paymentRequest.currencyCode = info["currencyCode"] as? String ?? ""
        paymentRequest.merchantIdentifier = info["merchantIdentifier"] as? String ?? ""

        guard let paymentSummaryItems = makePaymentSummaryItems(from: info) else {
            isHandlingResult = false
            result(nil)
            return
        }
        paymentRequest.paymentSummaryItems = paymentSummaryItems

        let present: () -> Void = { [weak self] in
            guard let self = self else { return }
            guard let controller = PKPaymentAuthorizationViewController(paymentRequest: paymentRequest) else {
                self.returnBraintreeError(result: result, error: NSError(domain: "flutter_braintree", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to present Apple Pay."]))
                self.isHandlingResult = false
                return
            }
            self.applePayResult = result
            self.applePayAuthorization = authorization
            self.applePayNonceReturned = false
            controller.delegate = self
            self.keyWindow()?.rootViewController?.present(controller, animated: true, completion: nil)
        }

        if bool(for: "collectDeviceData", in: call) ?? false {
            BTDataCollector(authorization: authorization).collectDeviceData { [weak self] data, _ in
                self?.applePayDeviceData = data
                present()
            }
        } else {
            applePayDeviceData = nil
            present()
        }
    }

    // MARK: - Shared result handling

    /// Resolves a tokenization result, optionally collecting device data, and treats a PayPal
    /// user-cancellation as a `null` result to preserve the historical Drop-in contract.
    private func finish(nonce: BTPaymentMethodNonce?, error: Error?, authorization: String, call: FlutterMethodCall, amount: String?, result: @escaping FlutterResult) {
        if let error = error {
            let nsError = error as NSError
            if nsError.domain == "com.braintreepayments.BTPayPalErrorDomain" && nsError.code == 1 {
                // .canceled — user backed out of the PayPal flow.
                isHandlingResult = false
                result(nil)
                return
            }
            returnBraintreeError(result: result, error: error)
            isHandlingResult = false
            return
        }

        guard let nonce = nonce else {
            isHandlingResult = false
            result(nil)
            return
        }

        var nonceDict = buildPaymentNonceDict(nonce: nonce)
        if let amount = amount {
            nonceDict["amount"] = amount
        }

        if bool(for: "collectDeviceData", in: call) ?? false {
            BTDataCollector(authorization: authorization).collectDeviceData { [weak self] data, _ in
                guard let self = self else { return }
                nonceDict["deviceData"] = data
                self.isHandlingResult = false
                result(nonceDict)
            }
        } else {
            isHandlingResult = false
            result(nonceDict)
        }
    }

    private func keyWindow() -> UIWindow? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    private func cleanupApplePay() {
        applePayResult = nil
        applePayAuthorization = nil
        applePayDeviceData = nil
        applePayNonceReturned = false
        isHandlingResult = false
    }
}

// MARK: - PKPaymentAuthorizationViewControllerDelegate

extension FlutterBraintreeCustomPlugin: PKPaymentAuthorizationViewControllerDelegate {
    public func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        guard let authorization = applePayAuthorization else {
            completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
            return
        }

        let applePayClient = BTApplePayClient(authorization: authorization)
        applePayClient.tokenize(payment) { [weak self] nonce, error in
            guard let self = self else { return }
            guard let nonce = nonce, error == nil else {
                completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                return
            }

            self.applePayNonceReturned = true
            var nonceDict = self.buildPaymentNonceDict(nonce: nonce)
            if let deviceData = self.applePayDeviceData {
                nonceDict["deviceData"] = deviceData
            }
            self.applePayResult?(nonceDict)
            completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
        }
    }

    public func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        let canceled = !applePayNonceReturned
        let pendingResult = applePayResult
        controller.dismiss(animated: true) { [weak self] in
            if canceled {
                pendingResult?(nil)
            }
            self?.cleanupApplePay()
        }
    }
}

// MARK: - BTThreeDSecureRequestDelegate

extension FlutterBraintreeCustomPlugin: BTThreeDSecureRequestDelegate {
    // Required by braintree_ios 7.x. We don't customize the lookup result, so
    // just continue the flow immediately.
    public func onLookupComplete(
        _ request: BTThreeDSecureRequest,
        lookupResult: BTThreeDSecureResult,
        next: @escaping () -> Void
    ) {
        next()
    }
}
