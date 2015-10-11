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
import HealthKit

struct CardioContext: Context {
}

class InterfaceController: WKInterfaceController {
    @IBOutlet weak var distanceLabel: WKInterfaceLabel!
    @IBOutlet weak var activeEnergyLabel: WKInterfaceLabel!
    @IBOutlet weak var heartRateLabel: WKInterfaceLabel!
    private var cardio: Cardio!

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // Configure interface objects here.
        let context = CardioContext()
        cardio = Cardio(context: context)
        cardio.authorize { result in
        }
        
        cardio.updateHandler = { quantity in
            if quantity.isCompatibleWithUnit(context.distanceUnit) {
                let distance = quantity.doubleValueForUnit(context.distanceUnit)
                self.distanceLabel.setText("\(distance)")
            } else if quantity.isCompatibleWithUnit(context.activeEnergyUnit) {
                let activeEnergy = quantity.doubleValueForUnit(context.activeEnergyUnit)
                self.activeEnergyLabel.setText("\(activeEnergy)")
            } else if quantity.isCompatibleWithUnit(context.heartRateUnit) {
                let heartRate = quantity.doubleValueForUnit(context.heartRateUnit)
                self.heartRateLabel.setText("\(heartRate)")
            }
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

    @IBAction func startWorkout(sender: WKInterfaceButton) {
        cardio.start { result in
        }
    }
    
    @IBAction func endWorkout(sender: WKInterfaceButton) {
        cardio.end { result in
            self.distanceLabel.setText(nil)
            self.activeEnergyLabel.setText(nil)
            self.heartRateLabel.setText(nil)
        }
    }
}
