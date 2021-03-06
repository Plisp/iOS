//
//  APIClient.swift
//  MyNSB
//
//  Created by Jayath Gunawardena on 17/12/18.
//  Copyright © 2018 Qwerp-Derp. All rights reserved.
//

import Foundation

import Alamofire
import AwaitKit
import PromiseKit
import SwiftyJSON

class FourUAPI {
    static func get() -> Promise<[Issue]> {
        return async {
            let body = try await(MyNSBRequest.get(path: "/4u/get"))[0].arrayValue
            return body.map { Issue(json: $0) }
        }
    }
}
