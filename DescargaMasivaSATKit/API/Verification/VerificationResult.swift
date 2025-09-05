//
//  VerificationResult.swift
//  Fidadces
//
//  Created by Pedro Ivan Salas Peña on 09/05/24.
//

import Foundation

enum VerificationResultError: Error {
    case httpError(statusCode: Int?)
}

class VerificationResult: NSObject {

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

extension VerificationResult: XMLParserDelegate {

    func parserDidEndDocument(_ parser: XMLParser) {
        if hasError {
            completionHandler(nil, nil, VerificationResultError.httpError(statusCode: response?.statusCode))
        } else {
            if contents.count > 0 {
                completionHandler(result, contents,nil)
            } else {
                completionHandler(result, nil,nil)
            }
        }
    }

    func parser(
        _ parser: XMLParser, didStartElement elementName: String,
        namespaceURI: String?, qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "VerificaSolicitudDescargaResult" {
            result = attributeDict
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if string.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
            contents.append(string)
        }
    }

}
