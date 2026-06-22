import Foundation

extension String {
    var csvEscaped: String {
        let escaped = replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    static var appName: Self {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? ""
    }
}

extension String.LocalizationValue {
    static var appName: Self {
        .init(stringLiteral: .appName)
    }
}
