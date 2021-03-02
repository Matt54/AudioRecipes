//
//  Modulation.swift
//  AudioRecipes
//
//  Created by Matt Pfeiffer on 2/26/21.
//

import Foundation
import AudioKit
import AVFoundation

extension Float {
    public func mappedExp(from source: ClosedRange<Float> = 0...1.0, to target: ClosedRange<Float> = 0...1.0) -> Float {
        let logStart2 = Float.log(target.lowerBound);
        let logStop2 = Float.log(target.upperBound);
        let scale = (logStop2-logStart2) / (source.upperBound-source.lowerBound);
        return Float.exp(logStart2 + scale*(self-source.lowerBound))
    }
    
    public func mappedExpInverted(from source: ClosedRange<Float> = 0...1.0, to target: ClosedRange<Float> = 0...1.0) -> Float {
        return target.upperBound - self.mappedExp(from: source, to: target) + target.lowerBound
    }
}

class ModulationMatrix {
    
    var modulations : [Modulation] = []
    var auParameterKeys : [String] = []
    
    func createNewModulation(frequency: Float64 = 1, table: Table) {
        let newModulation = Modulation(frequency: frequency, table: table)
        modulations.append(newModulation)
    }
    
    func addParameterToModulation(modulation: Modulation, auParameter: AUParameter, startValue: Float, endValue: Float, isLogRange: Bool = false) {
        modulation.addModulationTarget(auParameter: auParameter, startValue: startValue, endValue: endValue, isLogRange: isLogRange)
        if !auParameterKeys.contains(auParameter.keyPath) {
            auParameterKeys.append(auParameter.keyPath)
        }
    }
    
    func modulateMatrix() {
        for key in auParameterKeys {
            var modValues : [Float] = []
            for mod in modulations {
                for target in mod.targets {
                    if target.auParameter.keyPath == key {
                    }
                }
            }
            // apply value to parameter
        }
    }
    
}

class Modulation : Node, Identifiable {
    
    let id = UUID()
    
    var targets: [ModulationTarget] = []

    func addModulationTarget(auParameter: AUParameter, isLogRange: Bool = false) {
        targets.append(ModulationTarget(auParameter: auParameter, isLogRange: isLogRange))
    }
    
    func addModulationTarget(auParameter: AUParameter, startValue: Float, endValue: Float, isLogRange: Bool = false) {
        targets.append(ModulationTarget(auParameter: auParameter, startValue: startValue, endValue: endValue, isLogRange: isLogRange))
    }
    
    
    var frequency : Float64 = 440{
        didSet{
            lfo.frequency = frequency
        }
    }
    
    private var lfo : LFO
    
    init(frequency: Float64, table: Table = Table.init(.positiveSawtooth)){
        lfo = LFO(frequency: 0.1, table: table)
        super.init(avAudioNode: lfo.getSourceNode())
        lfo.lookupValueUpdateHandler = lookupValueUpdate
    }
    
    private func lookupValueUpdate(_ newValue: Float64) {
        modulateAllTargets(newValue)
    }
    
    func modulateAllTargets(_ newValue: Float64) {
        let lookupValue = Float(newValue)
        for target in targets {
            target.modulateParameter(lookupValue: lookupValue)
        }
    }
    
    public var modulationCallback: (Float64) -> Void = { _ in }
    
    struct ModulationTarget {
        var auParameter : AUParameter
        
        /// 0 to 1.0 range
        var anchorValue : Float
        
        /// -1.0 to 1.0 range
        /// anchorValue + modulationMagnitude must always be in a 0 to 1 range
        //var modulationMagnitude : Float
        
        /// must be known to determine the anchorValue
        var isLogRange : Bool
        
        var endValue : Float
        var startValue : Float
        
        
        init(auParameter: AUParameter, isLogRange: Bool = false){
            self.auParameter = auParameter
            anchorValue = auParameter.value
            self.startValue = auParameter.minValue
            self.endValue = auParameter.maxValue
            self.isLogRange = isLogRange
        }
        
        init(auParameter: AUParameter, startValue: Float, endValue: Float, isLogRange: Bool = false){
            self.auParameter = auParameter
            anchorValue = auParameter.value
            self.startValue = startValue
            self.endValue = endValue
            self.isLogRange = isLogRange
        }
        
        func modulateParameter(lookupValue: Float) {
            if !isLogRange {
                auParameter.value = anchorValue + lookupValue * (endValue - startValue)
            } else {
                if startValue < endValue {
                    auParameter.value = lookupValue.mappedExp(to: startValue...endValue)
                } else {
                    let value = lookupValue.mappedExpInverted(to: endValue...(startValue-endValue))
                    auParameter.value = anchorValue - value
                }
            }
        }
        
        /*func calculateModulationMagnitude() {
            
        }*/
        
        func calculateAnchorValue(currentValue: Float, minValue: Float, maxValue: Float) -> Float {
            if isLogRange {
                
            } else {
                
            }
            
            return 0
        }
        
    }
    
    fileprivate class LFO{

        var table: Table
        var realTime : Float64 = 0
        var frequency : Float64 = 1
        var lookupValue : Float64 = 0 {
            didSet {
                lookupValueUpdateHandler(lookupValue)
            }
        }
        public var lookupValueUpdateHandler: (Float64) -> Void = { _ in }
        
        private lazy var sourceNode = AVAudioSourceNode { silence, audioTimeStampPointer, frameCount, audioBufferList  in
            let audioTimeStamp = audioTimeStampPointer.pointee
            self.realTime = audioTimeStamp.mSampleTime / 44100
            self.lookupValue = self.getNextLookupValue(self.realTime)
            return noErr
        }
        
        init(frequency: Double = 0.1, table: Table){
            self.table = table
        }
        
        func getSourceNode() -> AVAudioSourceNode {
            return sourceNode
        }
        
        func getNextLookupValue(_ time: Float64) -> Float64 {
            
            let period = 1.0 / frequency
            
            // do something with the modulation value
            //determine what value from table to use (will end up between two values)
            let xVal = fmod(time, period) * Double(table.count-1) * Double(frequency)
            
            //return linear interpolation between the two values of the table
            let xFloor = Int(floor(xVal))
            let xCeil = Int(ceil(xVal))
            
            var newValue = table.content[xFloor] + (Float(xVal) - Float(xCeil) ) * (table.content[xCeil] - table.content[xFloor]) / Float(xCeil - xFloor)
            
            if newValue > 1 {
                newValue = 1
            } else if newValue < 0 {
                newValue = 0
            }
            
            return Float64( table.content[xFloor] + (Float(xVal) - Float(xCeil) ) * (table.content[xCeil] - table.content[xFloor]) / Float(xCeil - xFloor) )
        }
        
    }
    
}
