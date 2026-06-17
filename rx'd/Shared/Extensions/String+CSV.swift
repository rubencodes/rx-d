import Foundation

extension String {
    var csvEscaped: String {
        let escaped = self.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
