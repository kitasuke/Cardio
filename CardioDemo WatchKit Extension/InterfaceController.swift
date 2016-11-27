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
    fileprivate var cardio: Cardio!
    fileprivate var totalDistance: Double = 0
    fileprivate var totalActiveEnergy: Double = 0

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
        let context = Context()
        
        do {
            cardio = try Cardio(context: context)
            if !cardio.isAuthorized() {
                cardio.authorize() { result in
                    switch result {
                    case .success: break
                    case let .failure(error):
                        print(error)
                    }
                }
            }
        } catch let error {
            print(error)
        }
        
        cardio.distanceHandler = { [weak self] distance, total in
            self?.totalDistance = total
            self?.distanceLabel.setText((NSString(format: "%0.2f", total) as String) + "KM")
        }
        
        cardio.activeEnergyHandler = { [weak self] activeEnergy, total in
            self?.totalActiveEnergy = total
            self?.activeEnergyLabel.setText("\(Int(total))CAL")
        }
        
        cardio.heartRateHandler = { [weak self] heartRate, average in
            self?.heartRateLabel.setText("\(Int(heartRate))BPM")
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

    @IBAction func startWorkout(_ sender: WKInterfaceButton) { 
        switch cardio.workoutState {
        case .notStarted, .ended:
            startButton.setTitle("Pause")
            cardio.start { result in
                switch result {
                case .success: break
                case let .failure(error):
                    print(error)
                }
            }
        case .running:
            startButton.setTitle("Resume")
            cardio.pause()
        case .paused:
            startButton.setTitle("Pause")
            cardio.resume()
        }
    }
    
    @IBAction func endWorkout(_ sender: WKInterfaceButton) {
        cardio.end { [weak self] result in
            self?.distanceLabel.setText("0KM")
            self?.activeEnergyLabel.setText("0CAL")
            self?.heartRateLabel.setText("0BPM")
            self?.startButton.setTitle("Start")
            
            guard case .success = result else {
                print(result.error)
                return
            }
            
            self?.cardio.save() { result in
                guard case .success = result else {
                    print(result.error)
                    return
                }
                
                guard let workout = result.value else { return }
            }
        }
    }
}
