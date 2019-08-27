//
//  UUIDUtils.swift
//  QuickPayExample
//
//  Created on 01/03/2019.
//  Copyright © 2019 QuickPay. All rights reserved.
//

import Foundation

extension String {

    /**
     This function only works up to the length of a UUID
     **/
    static func randomString(len: Int) -> String {
        let randomString = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return String(randomString.prefix(len))
    }
    
}
