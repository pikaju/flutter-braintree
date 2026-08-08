import Flutter

public class FlutterBraintreePlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        FlutterBraintreeCustomPlugin.register(with: registrar)
    }
}
