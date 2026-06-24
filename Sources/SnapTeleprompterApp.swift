import SwiftUI

@main
struct SnapTeleprompterApp: App {
    @StateObject private var vm = TeleprompterViewModel()

    var body: some Scene {
        WindowGroup("Snap Teleprompter") {
            MainView(vm: vm)
                .frame(minWidth: 560, minHeight: 480)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
