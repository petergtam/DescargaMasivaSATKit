//
//  QueryEndpointResult.swift
//  Fidadces
//
//  Created by Pedro Ivan Salas Peña on 06/05/24.
//

import Foundation

struct QueryEndpointResultError : Error, Equatable {
    private enum Code: Equatable {
        case httpError(statusCode: Int?)
        case serializationFailed
    }
    
    private let code: Code
    
    static func httpError(statusCode: Int?) -> QueryEndpointResultError {
        .init(code: .httpError(statusCode: statusCode))
    }
    
    static var serializationFailed: QueryEndpointResultError {
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

class QueryEndpointResult : NSObject {
    
    var data: Data?
    var response: HTTPURLResponse?
    var completionHandler: (String?, Error?)->Void
    
    private var hasError = false
    private var result: [String: String] = [:]
    
    init(data: Data?, response: URLResponse?, completionHandler: @escaping (String?, Error?)->Void) {
        self.data = data
        self.response = response as? HTTPURLResponse
        self.completionHandler = completionHandler
        super.init()
    }
    
    func parse(){
        guard let response else {
            return
        }
        if !(200...299).contains(response.statusCode)  {
            hasError = true
        }
        if let data {
            let parser = XMLParser(data:data)
            parser.delegate = self
            parser.parse()
        }
    }
    
}

extension QueryEndpointResult: XMLParserDelegate {
    
    func parserDidEndDocument(_ parser: XMLParser) {
        if hasError {
            completionHandler(nil, QueryEndpointResultError.httpError(statusCode: response?.statusCode))
        }else{
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
            let response = ["result": encodedResult]
            var jsonResult: String?
            if let jsonData = try? JSONSerialization.data(withJSONObject: response, options: [.prettyPrinted,.sortedKeys]){
                jsonResult = String(data: jsonData, encoding: .utf8)
            }
            completionHandler(jsonResult,nil)
        }
    }
    
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName.contains("Result") {
            result = attributeDict
        }
    }
    
}
