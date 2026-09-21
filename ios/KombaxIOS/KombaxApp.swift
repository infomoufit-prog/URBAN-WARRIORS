import SwiftUI

@main
struct KombaxApp: App {
    @StateObject private var terminalBridge = KombaxTerminalBridge()
    var body: some Scene {
        WindowGroup {
            KombaxWebView(terminalBridge: terminalBridge)
                .ignoresSafeArea()
        }
    }
}
