import Foundation
import MickeyDomain

/// Settings as a portable JSON file, to back up or move to another Mac.
public enum SettingsTransfer {
    public static let fileExtension = "json"

    /// Pretty-printed JSON. The custom click sound is left out: its bookmark only means something on this Mac.
    public static func export(_ settings: Settings) -> Data {
        var portable = settings
        portable.click.customSound = nil
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(portable)) ?? Data()
    }

    /// Settings read from an exported file, repaired like stored ones. Nil when the data is not a Mickey settings file.
    public static func `import`(_ data: Data, keyCode: SettingsCodec.KeyCodeLookup? = nil) -> Settings? {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              object["schemaVersion"] is Int
        else { return nil }
        return SettingsCodec.decode(data, keyCode: keyCode)
    }

    /// `imported` applied to this Mac: what belongs to the machine (custom sound, login item, first-run flag) stays.
    public static func applying(_ imported: Settings, to current: Settings) -> Settings {
        var result = imported
        result.click.customSound = current.click.customSound
        result.general.launchAtLogin = current.general.launchAtLogin
        result.general.hasCompletedOnboarding = current.general.hasCompletedOnboarding
        return result
    }
}
