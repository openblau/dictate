import AppKit
import SwiftUI

/// Holds the editable list and persists every change, so there is no Save step.
@MainActor
final class CustomWordStore: ObservableObject {
    @Published var words: [CustomWord] {
        didSet { CustomWordPreference.save(words, to: defaults) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        words = CustomWordPreference.load(from: defaults)
    }

    func add() {
        words.append(CustomWord(heard: "", written: ""))
    }

    func remove(_ word: CustomWord) {
        words.removeAll { $0.id == word.id }
    }
}

struct CustomWordsView: View {
    @ObservedObject var store: CustomWordStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("When Dictate hears the words on the left, it writes the text on the right. Matching ignores capitals and spaces.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if store.words.isEmpty {
                Text("No custom words yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach($store.words) { $word in
                            HStack(spacing: 8) {
                                TextField("Heard, e.g. block swap", text: $word.heard)
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                                TextField("Written, e.g. Bloxwap", text: $word.written)
                                Button {
                                    store.remove(word)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Remove")
                            }
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }

            Button {
                store.add()
            } label: {
                Label("Add Word", systemImage: "plus")
            }
        }
        .padding(16)
        .frame(minWidth: 460, minHeight: 240)
    }
}

/// Dictate is a menu-bar-only app with no window scenes, so the editor lives in
/// one AppKit window that is created on first use and reused afterwards.
@MainActor
final class CustomWordsWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(
                rootView: CustomWordsView(store: CustomWordStore())
            ))
            window.title = "Custom Words"
            window.styleMask = [.titled, .closable, .resizable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 480, height: 300))
            window.center()
            self.window = window
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
