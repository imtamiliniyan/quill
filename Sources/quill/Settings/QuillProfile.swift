import Foundation

/// Local-only display profile — just a name shown in the Settings/General
/// tab. No account, no login, nothing that leaves this Mac.
enum QuillProfile {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let firstName = "profileFirstName"
        static let lastName = "profileLastName"
    }

    static var firstName: String {
        get { defaults.string(forKey: Key.firstName) ?? "" }
        set { defaults.set(newValue, forKey: Key.firstName) }
    }

    static var lastName: String {
        get { defaults.string(forKey: Key.lastName) ?? "" }
        set { defaults.set(newValue, forKey: Key.lastName) }
    }
}
