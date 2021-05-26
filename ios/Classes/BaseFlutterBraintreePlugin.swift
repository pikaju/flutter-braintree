import Foundation
import Flutter
import Braintree
import BraintreeDropIn

open class BaseFlutterBraintreePlugin: NSObject {
    internal var isHandlingResult = false;

    /**
     Will get the authorization for the current method call. This will basically check for a  *clientToken*, *tokenizationKey* or *authorization* property on the call.
     This does not take care about sending the error to the Flutter result.
     */
    internal func getAuthorization(call: FlutterMethodCall) -> String? {
        let clientToken = string(for: "clientToken", in: call)
        let tokenizationKey = string(for: "tokenizationKey", in: call)
        let authorizationKey = string(for: "authorization", in: call)

        guard let authorization = clientToken
            ?? tokenizationKey
            ?? authorizationKey else {
            return nil
        }

        return authorization
    }

    internal func buildPaymentNonceDict(nonce: BTPaymentMethodNonce?) -> [String: Any?] {
        [
            "nonce": nonce?.nonce,
            "typeLabel": nonce?.type,
            "description": nonce?.nonce,
            "isDefault": nonce?.isDefault
        ];
    }
    
    internal func returnAuthorizationMissingError (result: FlutterResult) {
        result(FlutterError(code: "braintree_error", message: "Authorization not specified (no clientToken or tokenizationKey)", details: nil))
    }
    
    internal func returnBraintreeError(result: FlutterResult, error: Error) {
        result(FlutterError(code: "braintree_error", message: error.localizedDescription, details: nil))
    }
    
    internal func returnAlreadyOpenError(result: FlutterResult) {
        result(FlutterError(code: "drop_in_already_running", message: "Cannot launch another Drop-in activity while one is already running.", details: nil));
    }

    internal func string(for key: String, in call: FlutterMethodCall) -> String? {
        return (call.arguments as? [String: Any])?[key] as? String
    }


    internal func bool(for key: String, in call: FlutterMethodCall) -> Bool? {
        return (call.arguments as? [String: Any])?[key] as? Bool
    }


    internal func dict(for key: String, in call: FlutterMethodCall) -> [String: Any]? {
        return (call.arguments as? [String: Any])?[key] as? [String: Any]
    }
}
