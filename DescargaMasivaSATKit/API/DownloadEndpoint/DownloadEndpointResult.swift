//
//  DownloadEndpointResult.swift
//  Fidadces
//
//  Created by Pedro Ivan Salas Peña on 11/05/24.
//

import Foundation

struct DownloadEndpointResultError : Error {
    private enum Code {
        case httpError(statusCode: Int?)
    }
    
    private let code: Code
    
    static func httpError(statusCode: Int?) -> DownloadEndpointResultError {
        .init(code: .httpError(statusCode: statusCode))
    }
    
    var localizedDescription: String {
        switch code {
        case .httpError(statusCode: let statusCode):
            return "HTTP error: \(statusCode ?? 0)"
        }
    }
}

class DownloadEndpointResult: NSObject {

    var data: Data?
    var response: HTTPURLResponse?
    var completionHandler: ([String: String]?, [String]?, Error?) -> Void

    private var hasError = false
    private var result: [String: String] = [:]
    private var contents: [String] = []

    init(
        data: Data?, response: URLResponse?,
        completionHandler: @escaping ([String: String]?, [String]?, Error?) -> Void
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
            completionHandler(nil, nil, DownloadEndpointResultError.httpError(statusCode: response?.statusCode))
        } else {
            if contents.count > 0 {
                completionHandler(result, contents, nil)
            } else {
                completionHandler(result, nil, nil)
            }
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
