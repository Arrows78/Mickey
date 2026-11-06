import Foundation

/// The text to show for `key` in the user's language: its translation from the app's `Localizable.strings`,
/// or the key itself (English) when it has none.
public func tr(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// `tr` for texts with values in them: the key holds `%@` or `%lld` placeholders.
public func trf(_ key: String, _ args: CVarArg...) -> String { String(format: tr(key), arguments: args) }
