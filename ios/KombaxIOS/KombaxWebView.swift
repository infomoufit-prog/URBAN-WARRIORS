import SwiftUI
import WebKit

struct KombaxWebView: UIViewRepresentable {
    @ObservedObject var terminalBridge: KombaxTerminalBridge

    func makeCoordinator() -> Coordinator { Coordinator(bridge: terminalBridge) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "kombaxTerminal")
        config.userContentController = controller
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let view = WKWebView(frame: .zero, configuration: config)
        terminalBridge.attach(webView: view)
        var request = URLRequest(url: URL(string: "https://kombax.es")!)
        request.cachePolicy = .reloadRevalidatingCacheData
        view.load(request)
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let bridge: KombaxTerminalBridge
        init(bridge: KombaxTerminalBridge) { self.bridge = bridge }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "kombaxTerminal", let payload = message.body as? [String: Any] else { return }
            bridge.handle(message: payload)
        }
    }
}
