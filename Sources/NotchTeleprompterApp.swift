import SwiftUI

@main
struct NotchTeleprompterApp: App {
    @StateObject private var vm = TeleprompterViewModel()

    var body: some Scene {
        WindowGroup("Notch Teleprompter") {
            MainView(vm: vm)
                .frame(minWidth: 560, minHeight: 480)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
