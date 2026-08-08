//
//  PKPaymentNetwork+.swift
//  flutter_braintree
//
//  Created by Desson Chan on 28/5/2022.
//

import Foundation
import PassKit

extension PKPaymentNetwork {
    static func mapRequestedNetwork(rawValue: Int) -> PKPaymentNetwork? {
        switch (rawValue) {
        case 0:
            return .visa
        case 1:
            return .masterCard
        case 2:
            return .amex
        case 3:
            return .discover
        default:
            return nil
        }
    }
}
