// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "braintree_flutter_plus",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .library(name: "braintree-flutter-plus", targets: ["braintree_flutter_plus"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/braintree/braintree_ios", from: "7.7.0")
    ],
    targets: [
        .target(
            name: "braintree_flutter_plus",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "BraintreeCore", package: "braintree_ios"),
                .product(name: "BraintreeCard", package: "braintree_ios"),
                .product(name: "BraintreePayPal", package: "braintree_ios"),
                .product(name: "BraintreeApplePay", package: "braintree_ios"),
                .product(name: "BraintreeDataCollector", package: "braintree_ios"),
                .product(name: "BraintreeThreeDSecure", package: "braintree_ios")
            ]
        )
    ]
)
