import SwiftUI
import SwiftData

@main
struct DocTemplateApp: App {

    var body: some Scene {

        WindowGroup {
            EditorDocumentView()
                .frame(minWidth: 1000, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {

            // MARK: - Native macOS Menu Bar Command Items

            SidebarCommands()

            CommandGroup(replacing: .newItem) {
                Button("New Document") {
                    // New document command
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("Format") {

                Button("Bold") {
                    // Bold shortcut
                }
                .keyboardShortcut("b", modifiers: .command)

                Button("Italic") {
                    // Italic shortcut
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("Underline") {
                    // Underline shortcut
                }
                .keyboardShortcut("u", modifiers: .command)
            }

            CommandMenu("Tools") {

                Button("Word Count...") {
                    // Word count shortcut
                }
                .keyboardShortcut(
                    "c",
                    modifiers: [.command, .shift]
                )

                Button("Help Me Write (Gemini AI)") {
                    // AI shortcut
                }
                .keyboardShortcut(
                    "g",
                    modifiers: [.command, .option]
                )
            }
        }
    }
}
