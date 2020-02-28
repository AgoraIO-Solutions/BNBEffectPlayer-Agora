//
//  FrameDurationLogger.swift
//  BanubaSdkApp
//
//  Created by Anton Kustov on 4/26/19.
//  Copyright © 2019 Banuba. All rights reserved.
//

import BanubaEffectPlayer

class FrameDurationLogger: BNBFrameDurationListener {
    
    class PerfData {
        static private let min_init: Float = Float.greatestFiniteMagnitude
        static private let max_init: Float = Float.leastNormalMagnitude
        
        var values = [Float]()
        
        var minDuration: Float = min_init
        var maxDuration: Float = max_init
        var valuesSum: Float = 0
        
        func isValid() -> Bool {
            return !values.isEmpty &&
                minDuration != FrameDurationLogger.PerfData.min_init &&
                maxDuration != FrameDurationLogger.PerfData.max_init
        }
        
        func averaged() -> Float {
            return valuesSum / Float(values.count)
        }
        
        func newValue(_ duration: Float) {
            // Sometimes take place strange  values like 409863.03
            // This values break formatted output as well
            // TODO(a.kustov): fix in effect player first wrong duration value
            // and remove this check
            if (duration > 10) {
                return
            }
            
            values.append(duration)
            
            if minDuration > duration {
                minDuration = duration
            }
            
            if maxDuration < duration {
                maxDuration = duration
            }
            
            valuesSum += duration
            
        }
        
    }
    
    class OutputFormatter {
        
        static let columnSeparator = ";"
        static let rowSeparator = "\n"
        
        var data = String()
        
        init(_ values: [[Float]]) {
            let columnsCount = values.count
            var columnSizes = [Int](repeating: 0, count: columnsCount)
            var maxColumnSize = 0;
            
            for col in 0 ..< columnsCount {
                columnSizes[col] = values[col].count
                maxColumnSize = max(maxColumnSize, columnSizes[col]);
            }
            
            for row in 0 ..< maxColumnSize {
                
                if columnsCount > 1 {
                    for col in 0 ..< columnsCount - 1 {
                        let columnValues: [Float] = values[col]
                        let columnSize = columnSizes[col]
                        
                        data += row >= columnSize ?
                            FrameDurationLogger.OutputFormatter.fmtEmptyCell(FmtPosition.Default) :
                            FrameDurationLogger.OutputFormatter.fmtVal(columnValues[row], pos: FmtPosition.Default);
                    }
                }
                
                let lastColumnValues = values[columnsCount - 1];
                let lastColumnSize = columnSizes[columnsCount - 1];
                
                data += row >= lastColumnSize ?
                    FrameDurationLogger.OutputFormatter.fmtEmptyCell(FmtPosition.Last) :
                    FrameDurationLogger.OutputFormatter.fmtVal(lastColumnValues[row], pos: FmtPosition.Last);
                
            }
            
        }
        
        enum FmtPosition {
            case Default
            case Last
        }
        
        static private func fmtVal(_ val: Float, pos: FmtPosition) -> String {
            let fmtStr = "%.3f" + (pos == FmtPosition.Last ? rowSeparator : columnSeparator)
            return String(format: fmtStr, val).padding(toLength: 6, withPad: " ", startingAt: 0)
        }
        
        static func fmtEmptyCell(_ pos: FmtPosition) -> String {
            return "     " + (pos == FmtPosition.Last ? rowSeparator : columnSeparator)
        }
        
    }
    
    var timer: Timer!
    static let timeoutMs = 30000.0
    
    let recognizer = PerfData()
    let camera = PerfData()
    let render = PerfData()
    
    func isDataValid() -> Bool {
        return recognizer.isValid() && camera.isValid() && render.isValid()
    }
    
    func printLine(v1: Float, v2: Float, v3: Float) {
        print(OutputFormatter([[v1], [v2], [v3]]).data);
    }
    
    func printValues() {
        print(OutputFormatter([recognizer.values, camera.values, render.values]).data)
    }
    
    func printMinMax() {
        print("Minimum")
        self.printLine(
            v1: self.recognizer.minDuration,
            v2: self.camera.minDuration,
            v3: self.render.minDuration)
        
        print("Maximum")
        self.printLine(
            v1: self.recognizer.maxDuration,
            v2: self.camera.maxDuration,
            v3: self.render.maxDuration)
    }
    
    func printAveraged() {
        print("Averaged")
        self.printLine(
            v1: self.recognizer.averaged(),
            v2: self.camera.averaged(),
            v3: self.render.averaged())
    }
    
    init() {
        print("Collecting duration values... Press button again to print.")
        timer = Timer.scheduledTimer(withTimeInterval: FrameDurationLogger.timeoutMs / 1000.0, repeats: true) { timer in
            self.printValues()
        }
    }
    
    func printResult() {
        timer!.invalidate()
        if !isDataValid() {
            print("No data to print")
            return
        }
        print("Frame duration, sec")
        print("Recognizer;Camera;Render")
        printValues()
        printMinMax()
        printAveraged()
    }
    
    func onRecognizerFrameDurationChanged(_ instant: Float, averaged: Float) {
        recognizer.newValue(instant)
    }
    
    func onCameraFrameDurationChanged(_ instant: Float, averaged: Float) {
        camera.newValue(instant)
    }
    
    func onRenderFrameDurationChanged(_ instant: Float, averaged: Float) {
        render.newValue(instant)
    }
    
}
