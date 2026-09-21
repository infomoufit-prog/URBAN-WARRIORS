import Foundation
import WebKit
import StripeTerminal

@MainActor
final class KombaxTerminalBridge: NSObject, ObservableObject, ConnectionTokenProvider, TerminalDelegate, TapToPayReaderDelegate {
    private weak var webView: WKWebView?
    private var token: String?
    private var tokenCompletion: ConnectionTokenCompletionBlock?
    private var saleId = ""
    private var clientSecret = ""
    private var locationId = ""
    private var subjectType = ""
    private var subjectId = ""

    override init() {
        super.init()
        if !Terminal.isInitialized {
            Terminal.initWithTokenProvider(self, delegate: self, offlineDelegate: nil, logLevel: .info)
        } else {
            Terminal.shared.delegate = self
        }
    }

    func attach(webView: WKWebView) { self.webView = webView }

    func handle(message: [String: Any]) {
        switch String(describing: message["action"] ?? "") {
        case "startTapToPay": start(payload: message)
        case "connectionToken": provide(token: String(describing: message["token"] ?? message["secret"] ?? ""))
        default: break
        }
    }

    func fetchConnectionToken(_ completion: @escaping ConnectionTokenCompletionBlock) {
        if let token, token.hasPrefix("pst_") {
            self.token = nil
            completion(token, nil)
            return
        }
        tokenCompletion = completion
        emit(name: "kombax-terminal-token-request", detail: [
            "request_id": UUID().uuidString,
            "subject_type": subjectType,
            "subject_id": subjectId
        ])
    }

    private func provide(token: String) {
        guard token.hasPrefix("pst_") else { return }
        if let completion = tokenCompletion {
            tokenCompletion = nil
            completion(token, nil)
        } else { self.token = token }
    }

    private func start(payload: [String: Any]) {
        saleId = String(describing: payload["sale_id"] ?? "")
        clientSecret = String(describing: payload["client_secret"] ?? "")
        locationId = String(describing: payload["location_id"] ?? "")
        token = String(describing: payload["connection_token"] ?? "")
        subjectType = String(describing: payload["subject_type"] ?? "")
        subjectId = String(describing: payload["subject_id"] ?? "")
        guard !saleId.isEmpty, clientSecret.hasPrefix("pi_"), clientSecret.contains("_secret_"), locationId.hasPrefix("tml_"), token?.hasPrefix("pst_") == true else {
            fail(code: "INVALID_TERMINAL_PAYLOAD", message: "KOMBAX recibió un payload Tap to Pay incompleto.")
            return
        }
        if Terminal.shared.connectionStatus == .connected {
            Terminal.shared.disconnectReader { [weak self] error in
                if let error { self?.fail(code: "DISCONNECT_FAILED", message: error.localizedDescription) }
                else { self?.connectAndProcess() }
            }
        } else { connectAndProcess() }
    }

    private func connectAndProcess() {
        do {
            let discovery = try TapToPayDiscoveryConfigurationBuilder().setSimulated(false).build()
            let connection = try TapToPayConnectionConfigurationBuilder(delegate: self, locationId: locationId)
                .setAutoReconnectOnUnexpectedDisconnect(true)
                .setTosAcceptancePermitted(true)
                .build()
            let easy = TapToPayEasyConnectConfiguration(discoveryConfiguration: discovery, connectionConfiguration: connection)
            Terminal.shared.easyConnect(easy) { [weak self] _, error in
                if let error { self?.fail(code: "TAP_TO_PAY_CONNECT_FAILED", message: error.localizedDescription); return }
                self?.retrieveAndProcess()
            }
        } catch { fail(code: "TAP_TO_PAY_CONNECT_FAILED", message: error.localizedDescription) }
    }

    private func retrieveAndProcess() {
        Terminal.shared.retrievePaymentIntent(clientSecret) { [weak self] intent, error in
            guard let self else { return }
            if let error { self.fail(code: "PAYMENT_RETRIEVE_FAILED", message: error.localizedDescription); return }
            guard let intent else { self.fail(code: "PAYMENT_RETRIEVE_FAILED", message: "PaymentIntent unavailable"); return }
            let collect = CollectPaymentIntentConfigurationBuilder().setSkipTipping(true).build()
            let confirm = ConfirmPaymentIntentConfigurationBuilder().build()
            Terminal.shared.processPaymentIntent(intent, collectConfig: collect, confirmConfig: confirm) { [weak self] result, error in
                guard let self else { return }
                if let error { self.fail(code: "PAYMENT_PROCESS_FAILED", message: error.localizedDescription); return }
                self.emit(name: "kombax-tap-to-pay-result", detail: ["ok": true, "sale_id": self.saleId, "payment_intent_id": result?.stripeId ?? "", "platform": "ios"])
                Terminal.shared.disconnectReader { _ in }
            }
        }
    }

    private func fail(code: String, message: String) {
        emit(name: "kombax-tap-to-pay-result", detail: ["ok": false, "sale_id": saleId, "error": code, "message": message, "platform": "ios"])
    }

    private func emit(name: String, detail: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(detail), let data = try? JSONSerialization.data(withJSONObject: detail), let json = String(data: data, encoding: .utf8) else { return }
        webView?.evaluateJavaScript("window.dispatchEvent(new CustomEvent(\"\(name)\",{detail:\(json)}));")
    }

    func terminal(_ terminal: Terminal, didChangeConnectionStatus status: ConnectionStatus) {}
    func terminal(_ terminal: Terminal, didChangePaymentStatus status: PaymentStatus) {}
    func reader(_ reader: Reader, didStartReconnect cancelable: Cancelable, reason: DisconnectReason) {}
    func readerDidReconnect(_ reader: Reader) {}
    func readerDidFailToReconnect(_ reader: Reader) {}
    func reader(_ reader: Reader, didDisconnect reason: DisconnectReason) {}
}
