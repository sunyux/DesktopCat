import Foundation

enum L10n {
    static let usesChinese = Locale.preferredLanguages.first?
        .lowercased()
        .hasPrefix("zh") == true

    static func text(_ chinese: String, _ english: String) -> String {
        usesChinese ? chinese : english
    }
}
