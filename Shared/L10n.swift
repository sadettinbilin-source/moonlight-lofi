import Foundation

enum L10n {
    static func tr(_ key: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: .main, value: key, comment: "")
    }

    static func tr(_ key: String, _ value: CVarArg) -> String {
        String.localizedStringWithFormat(tr(key), value)
    }
}
