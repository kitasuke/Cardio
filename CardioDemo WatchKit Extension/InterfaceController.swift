//
//  InterfaceController.swift
//  CardioDemo WatchKit Extension
//
//  Created by Yusuke Kita on 10/7/15.
//  Copyright © 2015 kitasuke. All rights reserved.
//

import WatchKit
import Foundation
import Cardio

class InterfaceController: WKInterfaceController {

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // Configure interface objects here.
        let context = Context()
        let cardio = Cardio(context: context)
        cardio.authorize { result -> Void in
            print(result)
        }
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

}
