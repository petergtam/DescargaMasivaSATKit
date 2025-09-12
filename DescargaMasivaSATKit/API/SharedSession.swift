//
//  SharedSession.swift
//  DescargaMasivaSATKit
//
//  Created by Pedro Ivan Salas Peña on 10/09/25.
//

import Foundation

protocol SharedSession {
    func data(for: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession : SharedSession { }
