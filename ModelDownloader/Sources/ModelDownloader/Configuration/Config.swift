import Foundation

/// Configuration object with dynamic member lookup, matching the original HUB implementation
@dynamicMemberLookup
internal struct Config: @unchecked Sendable {
    private let dictionary: [String: Any]

    internal init(_ dictionary: [String: Any]) {
        self.dictionary = dictionary
    }

    /// Convert camelCase string to snake_case
    func camelCase(_ string: String) -> String {
        let components: [Substring] = string.split(separator: "_")
        let mapped: [String] = components.enumerated()
            .map { $0.offset == 0 ? $0.element.lowercased() : $0.element.capitalized }
        return mapped.joined()
    }

    /// Convert snake_case string to camelCase  
    func uncamelCase(_ string: String) -> String {
        let scalars: String.UnicodeScalarView = string.unicodeScalars
        var result: String = ""

        var previousCharacterIsLowercase: Bool = false
        for scalar: UnicodeScalar in scalars {
            if CharacterSet.uppercaseLetters.contains(scalar) {
                if previousCharacterIsLowercase {
                    result += "_"
                }
                let lowercaseChar: String = Character(scalar).lowercased()
                result += lowercaseChar
                previousCharacterIsLowercase = false
            } else {
                result += String(scalar)
                previousCharacterIsLowercase = true
            }
        }

        return result
    }

    /// Dynamic member lookup for configuration values
    internal subscript(dynamicMember member: String) -> Self? {
        let key: String = dictionary[member] != nil ? member : uncamelCase(member)
        if let value: [String: Any] = dictionary[key] as? [String: Any] {
            return Self(value)
        }
        if let value = dictionary[key] {
            return Self(["value": value])
        }
        return nil
    }

    /// Get the raw value stored in this config
    internal var value: Any? {
        dictionary["value"]
    }

    /// Convenience accessors for common types
    internal var intValue: Int? { value as? Int }
    internal var boolValue: Bool { (value as? Bool) ?? false }
    internal var stringValue: String? { value as? String }

    /// Array value accessor that converts each element to Config
    internal var arrayValue: [Self] {
        guard let list: [Any] = value as? [Any] else {
            return []
        }
        return list.compactMap { element in
            guard let dict: [String: Any] = element as? [String: Any] else { return nil }
            return Self(dict)
        }
    }

    /// Token value as tuple (identifier, string)
    internal var tokenValue: (UInt, String)? { value as? (UInt, String) }
}
