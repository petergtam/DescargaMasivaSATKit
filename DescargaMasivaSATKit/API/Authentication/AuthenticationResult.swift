//
//  AuthenticationResult.swift
//  Fidadces
//
//  Created by Pedro Ivan Salas Peña on 02/05/24.
//

import Foundation

struct AuthenticationResultError: Error, Equatable {
    private enum Code: Equatable {
        case dateParsingFailed(contents: [String])
        case httpError(statusCode: Int?, contents: [String])
    }
    
    private let code: Code
    
    static func dateParsingFailed(contents: [String]) -> AuthenticationResultError {
        .init(code: .dateParsingFailed(contents: contents))
    }
    
    static func httpError(statusCode: Int?, contents: [String]) -> AuthenticationResultError {
        .init(code: .httpError(statusCode: statusCode, contents: contents))
    }
    
    var localizedDescription: String {
        switch code {
        case .dateParsingFailed(contents: let contents):
            return "Failed to parse date from contents: \(contents)"
        case .httpError(statusCode: let statusCode, contents: let contents):
            return "HTTP error \(statusCode ?? 0), withContents: \(contents)"
        }
    }
}

class AuthenticationResult : NSObject {
    
    var data: Data?
    var response: HTTPURLResponse?
    var completionHandler: (Date?,Date?,String?,Error?) -> Void
    
    private var contents: [String] = []
    private var hasError = false
    
    init(data: Data?, response: URLResponse?, completionHandler: @escaping (Date?,Date?,String?,Error?) -> Void) {
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

extension AuthenticationResult: XMLParserDelegate {
    
    func parserDidEndDocument(_ parser: XMLParser) {
        if hasError {
            completionHandler(nil,nil,nil,AuthenticationResultError.httpError(statusCode: response?.statusCode, contents: contents))
        }else{
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime,.withFractionalSeconds]
            guard let created = formatter.date(from: contents[0]), let expires = formatter.date(from: contents[1]) else{
                completionHandler(nil,nil,nil,AuthenticationResultError.dateParsingFailed(contents: contents))
                return
            }
            completionHandler(created,expires,contents[2],nil)
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if string.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
            contents.append(string)
        }
    }
}
