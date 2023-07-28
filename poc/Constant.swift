//
//  Constant.swift
//  poc
//
//  Created by Wama on 18/07/23.
//

import Foundation
import UIKit

//----------------------------
//MARK: - Environment Variable
//----------------------------
enum Environment {
    case test, production
}

var environment:Environment = Environment.test

var webURL: String {
    switch(environment) {
    case .production:
        return "https://happiai-eaf5d.web.app"
    case .test:
        return "https://wama-happi-test.web.app"
    }
}

//--------------------
//MARK: - Custom print
//--------------------
func _print(_ items: Any...) {
    #if DEBUG
    for item in items {
        print(item)
    }
    #endif
}

//--------------------
//MARK: - Storyboards
//--------------------
let _mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
