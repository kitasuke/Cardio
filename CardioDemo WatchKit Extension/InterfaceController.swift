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

struct Context: ContextType {
}

class InterfaceController: WKInterfaceController {
    @IBOutlet weak var distanceLabel: WKInterfaceLabel!
    @IBOutlet weak var activeEnergyLabel: WKInterfaceLabel!
    @IBOutlet weak var heartRateLabel: WKInterfaceLabel!
    @IBOutlet weak var startButton: WKInterfaceButton!
    private var cardio: Cardio!
    private var totalDistance: Double = 0
    private var totalActiveEnergy: Double = 0

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // Configure interface objects here.
        let context = Context()
        cardio = Cardio(context: context)
        if !cardio.isAuthorized() {
            cardio.authorize() { result in
                switch result {
                case .Success: break
                case let .Failure(error):
                    print(error)
                }
            }
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
        switch cardio.state {
        case .NotStarted, .Ended:
            startButton.setTitle("Pause")
            cardio.start { result in
                switch result {
                case .Success: break
                case let .Failure(error):
                    print(error)
                }
            }
        case .Running:
            startButton.setTitle("Resume")
            cardio.pause()
        case .Paused:
            startButton.setTitle("Pause")
            cardio.resume()
        }
    }
    
    @IBAction func endWorkout(sender: WKInterfaceButton) {
        cardio.end { result in
            self.distanceLabel.setText("0KM")
            self.activeEnergyLabel.setText("0CAL")
            self.heartRateLabel.setText("0BPM")
            
            guard case .Success = result else {
                print(result.error)
                return
            }
            
            self.cardio.save() { result in
                guard case .Success = result else {
                    print(result.error)
                    return
                }
                
                guard let workout = result.value else { return }
            }
        }
    }
}
