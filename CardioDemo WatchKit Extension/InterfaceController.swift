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
    private var totalDistance: Double = 0
    private var totalActiveEnergy: Double = 0

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // Configure interface objects here.
        let context = CardioContext()
        cardio = Cardio(context: context)
        cardio.authorize { result in
        }
        
        cardio.distanceHandler = { distance, total in
            self.totalDistance = total
            self.distanceLabel.setText((NSString(format: "%0.2f", self.totalDistance) as String) + "KM")
        }
        
        cardio.activeEnergyHandler = { activeEnergy, total in
            self.totalActiveEnergy = total
            self.activeEnergyLabel.setText("\(Int(self.totalActiveEnergy))CAL")
        }
        
        cardio.heartRateHandler = { heartRate, average in
            self.heartRateLabel.setText("\(Int(heartRate))BPM")
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
