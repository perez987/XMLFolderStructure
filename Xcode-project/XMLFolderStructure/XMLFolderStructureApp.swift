import SwiftUI

@main
struct XMLFolderStructureApp: App {
    
    @State private var isLanguageSelectorPresented = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .sheet(isPresented: $isLanguageSelectorPresented) {
                    LanguageSelectorView()
                }
        }
        
        // window resizability derived from the window’s content
        // macOS 13 Ventura or newer
        .windowResizability(.contentSize)
        
        // Language menu
        .commands {
            CommandMenu(NSLocalizedString("menu_language", comment: "Language menu")) {
                Button(NSLocalizedString("menu_select_language", comment: "Select Language menu item")) {
                    isLanguageSelectorPresented = true
                }
                .keyboardShortcut("l", modifiers: .command)
            }
        }
    }
}
