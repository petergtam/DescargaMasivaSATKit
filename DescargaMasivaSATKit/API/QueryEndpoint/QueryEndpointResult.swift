//
//  QueryEndpointResult.swift
//  Fidadces
//
//  Created by Pedro Ivan Salas Peña on 06/05/24.
//

import Foundation

struct QueryEndpointResultError : Error {
    private enum Code {
        case httpError(statusCode: Int?)
    }
    
    private let code: Code
    
    static func httpError(statusCode: Int?) -> QueryEndpointResultError {
        .init(code: .httpError(statusCode: statusCode))
    }
    
    var localizedDescription: String {
        switch code {
        case .httpError(statusCode: let statusCode):
            return "HTTP error: \(statusCode ?? 0)"
        }
    }
    
}

class QueryEndpointResult : NSObject {
    
    var data: Data?
    var response: HTTPURLResponse?
    var completionHandler: ([String:String]?, Error?)->Void
    
    private var hasError = false
    private var result: [String: String] = [:]
    
    init(data: Data?, response: URLResponse?, completionHandler: @escaping ([String:String]?, Error?)->Void) {
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
            completionHandler(result,nil)
        }
    }
    
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName.contains("Result") {
            result = attributeDict
        }
    }
    
}
