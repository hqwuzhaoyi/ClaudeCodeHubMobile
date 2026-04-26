import Foundation

struct EmptyBody: Encodable {}
struct EmptyResponse: Decodable {}

struct FlexibleEnvelope<Value: Decodable>: Decodable {
    let value: Value

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            for key in ["data", "result", "payload", "item", "value", "response"] {
                if let codingKey = DynamicCodingKey(stringValue: key),
                   container.contains(codingKey),
                   let decoded = try? container.decode(Value.self, forKey: codingKey) {
                    value = decoded
                    return
                }
            }
        }

        if let direct = try? Value(from: decoder) {
            value = direct
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "No supported envelope key found")
        )
    }
}

struct DynamicCodingKey: CodingKey, Hashable {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

extension KeyedDecodingContainer where K == DynamicCodingKey {
    func decodeString(forPossibleKeys keys: [String]) -> String? {
        for key in keys {
            guard let codingKey = DynamicCodingKey(stringValue: key), contains(codingKey) else { continue }
            if let value = try? decode(String.self, forKey: codingKey), !value.isEmpty { return value }
            if let value = try? decode(Int.self, forKey: codingKey) { return String(value) }
            if let value = try? decode(Double.self, forKey: codingKey) { return String(value) }
            if let value = try? decode(Bool.self, forKey: codingKey) { return value ? "true" : "false" }
        }
        return nil
    }

    func decodeDouble(forPossibleKeys keys: [String]) -> Double? {
        for key in keys {
            guard let codingKey = DynamicCodingKey(stringValue: key), contains(codingKey) else { continue }
            if let value = try? decode(Double.self, forKey: codingKey) { return value }
            if let value = try? decode(Int.self, forKey: codingKey) { return Double(value) }
            if let value = try? decode(String.self, forKey: codingKey) {
                let cleaned = value.replacingOccurrences(of: ",", with: "")
                if let double = Double(cleaned) { return double }
            }
        }
        return nil
    }

    func decodeInt(forPossibleKeys keys: [String]) -> Int? {
        for key in keys {
            guard let codingKey = DynamicCodingKey(stringValue: key), contains(codingKey) else { continue }
            if let value = try? decode(Int.self, forKey: codingKey) { return value }
            if let value = try? decode(Double.self, forKey: codingKey) { return Int(value) }
            if let value = try? decode(String.self, forKey: codingKey), let int = Int(value) { return int }
        }
        return nil
    }

    func decodeCursor(forPossibleKeys keys: [String]) -> UsageLogsCursor? {
        for key in keys {
            guard let codingKey = DynamicCodingKey(stringValue: key), contains(codingKey) else { continue }
            if let cursor = try? decode(UsageLogsCursor.self, forKey: codingKey) { return cursor }
        }
        return nil
    }


    func decodeBool(forPossibleKeys keys: [String]) -> Bool? {
        for key in keys {
            guard let codingKey = DynamicCodingKey(stringValue: key), contains(codingKey) else { continue }
            if let value = try? decode(Bool.self, forKey: codingKey) { return value }
            if let value = try? decode(Int.self, forKey: codingKey) { return value != 0 }
            if let value = try? decode(String.self, forKey: codingKey) {
                let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if ["true", "1", "yes", "y"].contains(normalized) { return true }
                if ["false", "0", "no", "n"].contains(normalized) { return false }
            }
        }
        return nil
    }

    func decodeDate(forPossibleKeys keys: [String], timeZone: TimeZone? = nil) -> Date? {
        for key in keys {
            guard let codingKey = DynamicCodingKey(stringValue: key), contains(codingKey) else { continue }
            if let value = try? decode(Date.self, forKey: codingKey) { return value }
            if let seconds = try? decode(Double.self, forKey: codingKey) {
                return Date(timeIntervalSince1970: normalizedUnixTimestamp(seconds))
            }
            if let raw = try? decode(String.self, forKey: codingKey) {
                if let date = AppFormatters.parseDate(raw, timeZone: timeZone) { return date }
                if let seconds = Double(raw) { return Date(timeIntervalSince1970: normalizedUnixTimestamp(seconds)) }
            }
        }
        return nil
    }

    private func normalizedUnixTimestamp(_ value: Double) -> Double {
        value > 9_999_999_999 ? value / 1_000 : value
    }
}
