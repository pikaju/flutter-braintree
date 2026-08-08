#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'braintree_flutter_plus'
  s.version          = '6.0.0'
  s.summary          = 'A Flutter plugin for Braintree'
  s.description      = <<-DESC
  A Flutter plugin that wraps the native Braintree Drop-In UI SDKs.
                       DESC
  s.homepage         = 'https://github.com/Pikaju/FlutterBraintree'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Julien Scholz' => '' }
  s.source           = { :path => '.' }
  # Sources live under the Swift Package layout so the plugin supports both
  # CocoaPods and Swift Package Manager.
  s.source_files = 'braintree_flutter_plus/Sources/braintree_flutter_plus/**/*.swift'
  s.dependency 'Flutter'
  # braintree-ios-drop-in has no v6/v7 release (frozen at 9.14.0, pinned to Braintree ~> 5.27),
  # so the native Drop-In SDK is removed. Drop-In is replaced by a Flutter-side payment sheet.
  s.dependency 'Braintree', '~> 7.7'
  s.dependency 'Braintree/Card', '~> 7.7'
  s.dependency 'Braintree/PayPal', '~> 7.7'
  s.dependency 'Braintree/ApplePay', '~> 7.7'
  s.dependency 'Braintree/DataCollector', '~> 7.7'
  s.dependency 'Braintree/ThreeDSecure', '~> 7.7'
  s.ios.deployment_target = '16.0'
  s.swift_version = '5.10'
end