import Foundation

/// Compares dotted version strings like "1.0.1" or release tags like "v1.2".
public enum AppVersion {
    /// Whether `candidate` is a later version than `current`, comparing each dotted
    /// component numerically (so 1.0.10 > 1.0.9, and 1.1 == 1.1.0).
    public static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let a = components(of: candidate)
        let b = components(of: current)
        for index in 0..<max(a.count, b.count) {
            let left = index < a.count ? a[index] : 0
            let right = index < b.count ? b[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    /// "v1.2.3-beta" → [1, 2, 3]: drops a leading "v" and anything after a component's digits.
    private static func components(of version: String) -> [Int] {
        var trimmed = version.trimmingCharacters(in: .whitespaces)
        if trimmed.lowercased().hasPrefix("v") { trimmed.removeFirst() }
        return trimmed.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
    }
}
