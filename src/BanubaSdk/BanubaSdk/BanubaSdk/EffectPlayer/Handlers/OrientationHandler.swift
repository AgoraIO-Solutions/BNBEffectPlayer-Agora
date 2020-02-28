//
//  DeviceOrientation.swift
//  Easy Snap
//
//  Created by Victor Privalov on 7/12/18.
//  Copyright © 2018 Banuba. All rights reserved.
//

import CoreMotion

extension BanubaSdkManager {
    
    class OrientationHandler {
        
        private let motionManager = CMMotionManager()
        private let operationQueue = OperationQueue()
        private let dispatchQueue = DispatchQueue(label: "com.banubaSdk.orientationQueue")
        
        private struct Config {
            // Smaller values makes it much sensitive to detect an orientation change. [0 to 1]
            static let motionLimit: Double = 0.6
            // Update interval in seconds
            static let updateInterval: Double = 0.2
        }
        
        private var currentDeviceOrientation = UIDeviceOrientation.portrait
        public var deviceOrientation : UIDeviceOrientation {
            var orientation = UIDeviceOrientation.portrait
            dispatchQueue.sync {
                orientation = self.currentDeviceOrientation
            }
            return orientation
        }
        
        init() {
            self.operationQueue.underlyingQueue = self.dispatchQueue
            self.motionManager.accelerometerUpdateInterval = Config.updateInterval
        }
        
        func start() {
            self.motionManager.startAccelerometerUpdates(to: self.operationQueue) { [weak self] (data, error) in
                guard let `self` = self, let accelerometerData = data else { return }
                
                let newDeviceOrientation: UIDeviceOrientation
                if (accelerometerData.acceleration.x >= Config.motionLimit) {
                    newDeviceOrientation = .landscapeLeft
                }
                else if (accelerometerData.acceleration.x <= -Config.motionLimit) {
                    newDeviceOrientation = .landscapeRight
                }
                else if (accelerometerData.acceleration.y <= -Config.motionLimit) {
                    newDeviceOrientation = .portrait
                }
                else if (accelerometerData.acceleration.y >= Config.motionLimit) {
                    newDeviceOrientation = .portraitUpsideDown
                }
                else {
                    return
                }
                self.currentDeviceOrientation = newDeviceOrientation
            }
        }
        
        func stop() {
            motionManager.stopAccelerometerUpdates()
        }
        
        deinit {
            stop()
        }
    }
}

