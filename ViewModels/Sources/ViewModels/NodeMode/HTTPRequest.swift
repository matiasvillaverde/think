import Foundation

internal struct HTTPRequest: Sendable {
    let method: String
    let path: String
    let queryItems: [URLQueryItem]
    let headers: [String: String]
    let body: Data
}

internal struct HTTPResponse: Sendable {
    let statusCode: Int
    let headers: [String: String]
    let body: Data

    func serialized() -> Data {
        var lines: [String] = []
        lines.append("HTTP/1.1 \(statusCode) \(Self.reasonPhrase(for: statusCode))")

        var finalHeaders: [String: String] = headers
        finalHeaders["Content-Length"] = "\(body.count)"
        finalHeaders["Connection"] = "close"
        if finalHeaders["Content-Type"] == nil {
            finalHeaders["Content-Type"] = "application/json"
        }

        for (key, value) in finalHeaders {
            lines.append("\(key): \(value)")
        }
        lines.append("")
        let headerData: Data = lines.joined(separator: "\r\n").data(using: .utf8) ?? Data()
        return headerData + body
    }

    private static func reasonPhrase(for status: Int) -> String {
        switch status {
        case 200:
            return "OK"

        case 201:
            return "Created"

        case 400:
            return "Bad Request"

        case 401:
            return "Unauthorized"

        case 404:
            return "Not Found"

        case 500:
            return "Internal Server Error"

        default:
            return "OK"
        }
    }
}

internal enum HTTPParser {
    static func parse(from buffer: inout Data) -> HTTPRequest? {
        guard let headerRange = buffer.range(of: Data("\r\n\r\n".utf8)) else {
            return nil
        }

        let headerData: Data = buffer.subdata(in: 0..<headerRange.lowerBound)
        guard let headerString: String = String(data: headerData, encoding: .utf8) else {
            return nil
        }

        let lines: [Substring] = headerString.split(separator: "\r\n")
        guard let requestLine: Substring = lines.first else {
            return nil
        }
        let parts: [Substring] = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            return nil
        }

        let method: String = String(parts[0])
        let urlString: String = String(parts[1])

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let segments: [Substring] = line.split(separator: ":", maxSplits: 1)
            guard segments.count == 2 else {
                continue
            }
            let key: String = segments[0].trimmingCharacters(in: .whitespaces).lowercased()
            let value: String = segments[1].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        let contentLength: Int = Int(headers["content-length"] ?? "") ?? 0
        let bodyStart: Data.Index = headerRange.upperBound
        let bodyEnd: Data.Index = bodyStart + contentLength
        guard buffer.count >= bodyEnd else {
            return nil
        }

        let body: Data = buffer.subdata(in: bodyStart..<bodyEnd)
        buffer.removeSubrange(0..<bodyEnd)

        let urlComponents: URLComponents? = URLComponents(string: "http://localhost\(urlString)")
        let path: String = urlComponents?.path ?? urlString
        let queryItems: [URLQueryItem] = urlComponents?.queryItems ?? []

        return HTTPRequest(
            method: method,
            path: path,
            queryItems: queryItems,
            headers: headers,
            body: body
        )
    }
}
