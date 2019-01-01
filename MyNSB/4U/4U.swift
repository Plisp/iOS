//
//  4U.swift
//  MyNSB
//
//  Created by Jayath Gunawardena on 26/11/18.
//  Copyright © 2018 Qwerp-Derp. All rights reserved.
//

import Foundation
import UIKit
import Alamofire
import PromiseKit
import SwiftyJSON

private func fetch4U() -> Promise<[Event]> {
    return firstly {
        Alamofire.request("http://35.244.66.186:8080/api/v1/4U/Get")
            .validate()
            .responseJSON()
        }.map { json, response in
            let body = JSON(json)["Message"]["Body"][0].arrayValue
            
            return body.map { eventJson in
                return Event(contents: eventJson)
                }.sorted { first, second in
                    first.start < second.start
            }
    }
}

private func get4U() {
    Alamofire.request("https://github.com/MyNSB/API/blob/master/src/4U/Get/main.go").responseJSON { response in
        if let result = response.result.value {
            let json = JSON(result)
            print(json["url"])
            print(json["explanation"])
        }
    }
}
