#import "FlutterBraintreePlugin.h"
#import <flutter_braintree/flutter_braintree-Swift.h>

@implementation FlutterBraintreePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterBraintreePlugin registerWithRegistrar:registrar];
}
@end
