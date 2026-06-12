import Carbon
import Foundation

struct InputSource: Equatable {
    let raw: TISInputSource

    var id: String {
        raw.id ?? UUID().uuidString
    }

    var localizedName: String {
        raw.localizedName ?? "Unknown"
    }

    var isSelected: Bool {
        raw.isSelected
    }

    func select() {
        TISSelectInputSource(raw)
    }
}

final class InputSourceController {
    func currentSourceName() -> String {
        currentSelectableSource()?.localizedName ?? "Unknown"
    }

    func selectNextSource() {
        let sources = selectableSources()
        guard !sources.isEmpty else { return }

        if let current = currentSelectableSource(),
           let index = sources.firstIndex(where: { $0.id == current.id }) {
            sources[(index + 1) % sources.count].select()
            return
        }

        sources[0].select()
    }

    private func currentSelectableSource() -> InputSource? {
        if let selected = selectableSources().first(where: { $0.isSelected }) {
            return selected
        }

        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }
        return InputSource(raw: source)
    }

    private func selectableSources() -> [InputSource] {
        guard let sourceList = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }

        return sourceList
            .filter { $0.category == (kTISCategoryKeyboardInputSource as String) && $0.isSelectable }
            .map(InputSource.init(raw:))
    }
}

private extension TISInputSource {
    var category: String? {
        property(for: kTISPropertyInputSourceCategory)
    }

    var isSelectable: Bool {
        boolProperty(for: kTISPropertyInputSourceIsSelectCapable)
    }

    var isSelected: Bool {
        boolProperty(for: kTISPropertyInputSourceIsSelected)
    }

    var id: String? {
        property(for: kTISPropertyInputSourceID)
    }

    var localizedName: String? {
        property(for: kTISPropertyLocalizedName)
    }

    func property<T>(for key: CFString) -> T? {
        guard let unmanaged = TISGetInputSourceProperty(self, key) else {
            return nil
        }
        return Unmanaged<AnyObject>.fromOpaque(unmanaged).takeUnretainedValue() as? T
    }

    func boolProperty(for key: CFString) -> Bool {
        guard let value: NSNumber = property(for: key) else {
            return false
        }
        return value.boolValue
    }
}
