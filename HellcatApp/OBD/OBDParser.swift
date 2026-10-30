import Foundation

/// A mode 01 parameter we poll from the engine computer.
struct OBDPID {
    let code: UInt8
    let decode: ([UInt8]) -> Double?

    var command: String { String(format: "01%02X", Int(code)) }

    static let rpm = OBDPID(code: 0x0C) { b in b.count >= 2 ? (Double(b[0]) * 256 + Double(b[1])) / 4 : nil }
    static let speed = OBDPID(code: 0x0D) { b in b.first.map { Double($0) } }
    static let coolantTemp = OBDPID(code: 0x05) { b in b.first.map { Double($0) - 40 } }
    static let intakeTemp = OBDPID(code: 0x0F) { b in b.first.map { Double($0) - 40 } }
    static let manifoldPressure = OBDPID(code: 0x0B) { b in b.first.map { Double($0) } }
    static let barometricPressure = OBDPID(code: 0x33) { b in b.first.map { Double($0) } }
    static let throttle = OBDPID(code: 0x11) { b in b.first.map { Double($0) * 100 / 255 } }
    static let moduleVoltage = OBDPID(code: 0x42) { b in b.count >= 2 ? (Double(b[0]) * 256 + Double(b[1])) / 1000 : nil }
    static let oilTemp = OBDPID(code: 0x5C) { b in b.first.map { Double($0) - 40 } }
}

enum OBDParser {
    /// Hex-only lines of an adapter response, with spaces and CAN frame prefixes ("0:") removed.
    /// Status text such as "SEARCHING..." is dropped.
    static func hexLines(_ response: String) -> [String] {
        response
            .components(separatedBy: CharacterSet(charactersIn: "\r\n"))
            .map { line -> String in
                let stripped = line.replacingOccurrences(of: " ", with: "")
                if let colon = stripped.firstIndex(of: ":") {
                    return String(stripped[stripped.index(after: colon)...])
                }
                return stripped
            }
            .filter { !$0.isEmpty && $0.allSatisfy(\.isHexDigit) }
    }

    static func bytes(fromHex hex: Substring) -> [UInt8] {
        var result: [UInt8] = []
        var index = hex.startIndex
        while let next = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) {
            if let byte = UInt8(hex[index..<next], radix: 16) { result.append(byte) }
            index = next
        }
        return result
    }

    /// Data bytes following "41 <pid>" in a mode 01 response.
    static func dataBytes(for pid: UInt8, in response: String) -> [UInt8]? {
        let header = String(format: "41%02X", Int(pid))
        for line in hexLines(response) {
            if let range = line.range(of: header) {
                return bytes(fromHex: line[range.upperBound...])
            }
        }
        return nil
    }

    /// Stored trouble codes from a mode 03 response, e.g. ["P0300", "P0420"].
    static func troubleCodes(in response: String) -> [String] {
        var lines = hexLines(response)
        // A multi-frame CAN reply starts with a 3-digit byte count line.
        if let first = lines.first, first.count == 3 { lines.removeFirst() }
        let joined = lines.joined()
        guard let range = joined.range(of: "43") else { return [] }

        var data = bytes(fromHex: joined[range.upperBound...])
        // On CAN the first byte is the number of codes, which makes the byte count odd.
        if data.count % 2 == 1 { data.removeFirst() }

        var codes: [String] = []
        var i = 0
        while i + 1 < data.count {
            let a = data[i], b = data[i + 1]
            i += 2
            if a == 0 && b == 0 { continue }
            let letter = ["P", "C", "B", "U"][Int(a >> 6)]
            codes.append(letter + String(format: "%X%X%02X", Int((a >> 4) & 0x3), Int(a & 0x0F), Int(b)))
        }
        return codes
    }
}
