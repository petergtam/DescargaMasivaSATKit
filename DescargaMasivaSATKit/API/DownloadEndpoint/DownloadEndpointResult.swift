//
//  DownloadEndpointResult.swift
//  Fidadces
//
//  Created by Pedro Ivan Salas Peña on 11/05/24.
//

import Foundation

struct DownloadEndpointResultError : Error, Equatable {
    private enum Code: Equatable {
        case httpError(statusCode: Int?)
        case serializationFailed
    }
    
    private let code: Code
    
    static func httpError(statusCode: Int?) -> DownloadEndpointResultError {
        .init(code: .httpError(statusCode: statusCode))
    }
    
    static var serializationFailed: DownloadEndpointResultError {
        .init(code: .serializationFailed)
    }

    var localizedDescription: String {
        switch code {
        case .httpError(statusCode: let statusCode):
            return "HTTP error: \(statusCode ?? 0)"
        case .serializationFailed:
            return "Serialization failed"
        }
    }
}

class DownloadEndpointResult: NSObject {

    var data: Data?
    var response: HTTPURLResponse?
    var completionHandler: (String?, Error?) -> Void

    private var hasError = false
    private var result: [String: String] = [:]
    private var contents: [String] = []

    init(
        data: Data?, response: URLResponse?,
        completionHandler: @escaping (String?, Error?) -> Void
    ) {
        self.data = data
        self.response = response as? HTTPURLResponse
        self.completionHandler = completionHandler
        super.init()
    }

    func parse() {
        guard let response else {
            return
        }
        if !(200...299).contains(response.statusCode) {
            hasError = true
        }
        if let data {
            let parser = XMLParser(data: data)
            parser.delegate = self
            parser.parse()
        }
    }

}

extension DownloadEndpointResult: XMLParserDelegate {

    func parserDidEndDocument(_ parser: XMLParser) {
        if hasError {
            completionHandler(nil, DownloadEndpointResultError.httpError(statusCode: response?.statusCode))
        } else {
            let cleanedResult = result.filter { !$0.key.starts(with: "xmlns") }
            let encodedResult = cleanedResult.reduce([:]) { partialResult, element in
                var partialResult = partialResult
                if let intValue = Int(element.value) {
                    partialResult[element.key] = intValue
                }else {
                    partialResult[element.key] = element.value
                }
                return partialResult
            }
            var response: [String: Any] = ["result": encodedResult]
            if contents.count > 0 {
                response["contents"] = contents
            }
            var jsonResult: String?
            if let jsonData = try? JSONSerialization.data(withJSONObject: response, options: [.prettyPrinted,.sortedKeys]){
                jsonResult = String(data: jsonData, encoding: .utf8)
            }
            completionHandler(jsonResult, nil)
        }
    }

    func parser(
        _ parser: XMLParser, didStartElement elementName: String,
        namespaceURI: String?, qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "h:respuesta" {
            result = attributeDict
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if string.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
            contents.append(string)
        }
    }

}
