import Foundation
import AudioKit
import AVFoundation

/// things we need to remember about a AUParameter
struct ParameterInfo{
    var anchorValue : Float // basically just the starting AUParameter.value before we modulate it (think position a knob is pointing)
    var isLogRange : Bool
}

/// keeps track of many modulations - glue for the many to many relationship between modulations and AUParameters
class ModulationManager : Node {
    
    fileprivate var lfoManager : LFOManager
    var anchorValueDictionary = [String: ParameterInfo]()
    var modulations : [Modulation] = []
    var auParameters : [AUParameter] = []
    
    init(sampleRate: Double) {
        lfoManager = LFOManager(sampleRate: sampleRate)
        super.init(avAudioNode: lfoManager.getSourceNode())
        lfoManager.lookupsCompleteHandler = modulateMatrix
    }
    
    func createNewModulation(frequency: Float = 1, table: Table) -> Modulation {
        let newModulation = Modulation(frequency: frequency, table: table)
        modulations.append(newModulation)
        let lfo = newModulation.getLFO()
        lfoManager.addLFO(lfo: lfo)
        return newModulation
    }
    
    func addParameterToModulation(modulation: Modulation, auParameter: AUParameter, isLogRange: Bool = false) {
        modulation.addModulationTarget(auParameter: auParameter, isLogRange: isLogRange)
        //need to know if this is a parameter we haven't seen yet to hold the reference and anchor value
        if !auParameters.contains(auParameter) {
            auParameters.append(auParameter)
            let anchorValue = calculateRangeValueFromParameterValue(auParameter.value, min: auParameter.minValue, max: auParameter.maxValue, isLogRange: isLogRange)
            let parameterInfo = ParameterInfo(anchorValue: anchorValue, isLogRange: isLogRange)
            anchorValueDictionary[auParameter.keyPath] = parameterInfo
        }
    }
    
    func adjustMagnitudeForParameterModulation(modulation: Modulation, auParameter: AUParameter, newMagnitude: Float) {
        if let mod = modulation.targets.first(where: {$0.auParameterKey == auParameter.keyPath}) {
            mod.modulationMagnitude = newMagnitude
        }
    }
    
    func setModulationMagnitudeToParameterValue(modulation: Modulation, auParameter: AUParameter, parameterValue: Float){
        if let modTarget = modulation.targets.first(where: {$0.auParameterKey == auParameter.keyPath}) {
            let rangeValue = calculateRangeValueFromParameterValue(parameterValue, min: auParameter.minValue, max: auParameter.maxValue, isLogRange: modTarget.isLogRange)
            if let parameterInfo = anchorValueDictionary[auParameter.keyPath] {
                modTarget.modulationMagnitude = rangeValue - parameterInfo.anchorValue
            }
        }
    }
    
    func calculateRangeValueFromParameterValue(_ parameterValue: Float, min: Float, max: Float, isLogRange: Bool) -> Float {
        if isLogRange {
            return parameterValue.mappedLog10(from: min...max)
        } else {
            return parameterValue.mapped(from: min...max)
        }
    }
    
    func calculateParameterValueFromRangeValue(_ rangeValue: Float, min: Float, max: Float, isLogRange: Bool) -> Float {
        if isLogRange {
            return rangeValue.mappedExp(to: min...max)
        } else {
            return rangeValue.mapped(to: min...max)
        }
    }
    
    func modulateMatrix() {
        for auParameter in auParameters {
            
            var modValue : Float = 0
            for modulation in modulations {
                modValue += modulation.getModifierValueForParameter(auParameterKey: auParameter.keyPath)
            }
            
            let parameterInfo = anchorValueDictionary[auParameter.keyPath]!
            let rangeValue = parameterInfo.anchorValue + modValue
            let parameterValue = calculateParameterValueFromRangeValue(rangeValue, min: auParameter.minValue, max: auParameter.maxValue, isLogRange: parameterInfo.isLogRange)
            
            if auParameter.minValue > parameterValue {
                auParameter.value = auParameter.minValue
            } else if auParameter.maxValue < parameterValue {
                auParameter.value = auParameter.maxValue
            } else {
                auParameter.value = parameterValue
            }
            
        }
    }

}

/// A modulation takes an LFO value and applies it to one or more Modulation Targets (can be thought of as simply AUParameters - there's just some extra book keeping required)
class Modulation {
    
    
    var targets: [ModulationTarget] = []
    
    private var lfo : LFO
    var frequency : Float {
        didSet{
            lfo.frequency = frequency
        }
    }
    
    init(frequency: Float, table: Table = Table.init(.positiveSawtooth)){
        lfo = LFO(frequency: frequency, table: table)
        self.frequency = frequency
    }

    func addModulationTarget(auParameter: AUParameter, isLogRange: Bool = false){
        let modulationTarget = ModulationTarget(auParameter: auParameter, isLogRange: isLogRange)
        targets.append(modulationTarget)
    }

    func getLFO() -> LFO {
        return lfo
    }
    
    func getModifierValueForParameter(auParameterKey: String) -> Float {
        if let modulationTarget = targets.first(where: {$0.auParameterKey == auParameterKey}){
            return modulationTarget.getModulationContribution(Float(lfo.lookupValue))
        } else {
            return 0
        }
    }
    
    class ModulationTarget {
        /// 0 to 1.0 range
        /// anchorValue + modulationMagnitude must always be in a 0 to 1 range
        var anchorValue : Float
        
        /// -1.0 to 1.0 range
        /// anchorValue + modulationMagnitude must always be in a 0 to 1 range
        var modulationMagnitude : Float = 0
        
        /// must be known to determine the anchorValue
        var isLogRange : Bool
        
        var auParameterKey : String
        
        init(auParameter: AUParameter, isLogRange: Bool = false){
            //self.auParameter = auParameter
            self.isLogRange = isLogRange
            if isLogRange {
                anchorValue = auParameter.value.mappedLog10(from: auParameter.minValue...auParameter.maxValue)
            } else {
                anchorValue = auParameter.value.mapped(from: auParameter.minValue...auParameter.maxValue)
            }
            auParameterKey = auParameter.keyPath
        }
        
        /// gets the range amount to move from the anchor value
        func getModulationContribution(_ lookupValue: Float) -> Float {
            return lookupValue * modulationMagnitude
        }
        
        /// this validation prevents anchorValue + modulationMagnitude from leaving a 0 to 1 range
        func setModulationMagnitude(_ desiredModulationMagnitude: Float) -> Float {
            if desiredModulationMagnitude + anchorValue >= 0 && desiredModulationMagnitude + anchorValue <= 1 {
                return desiredModulationMagnitude
            } else {
                if desiredModulationMagnitude >= 0 {
                    return 1.0 - anchorValue
                } else {
                    return anchorValue - 0.0
                }
            }
        }
    }
}

/// Connects to the audio chain (generates silence), updates the lookup value of many LFOs during each audio block, and provides a callback to let the modulation manager know it's time to update AU Parameter values
fileprivate class LFOManager{

    /// callback to let the modulation manager know it's time to update the AU Parameter values
    var lookupsCompleteHandler: () -> Void = {}
    
    /// current sample rate
    private var sampleRate : Double
    
    /// Each seperate modulation has it's own lfo
    private var lfos : [LFO] = []
    
    /// This prevents huge realTime values right out of the gate - this idea needs works - large audioTimeStamp.mSampleTime values cause wild results in fmod during the lookup method of the LFOs
    private var startTime : Double = 0
    
    /// Flag to make sure we only set the startTime once
    private var hasStarted : Bool = false

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    /// The sourceNode links into the audio chain and triggers the lookup value updates and subsequent callback to the modulation manager
    private lazy var sourceNode : AVAudioSourceNode = AVAudioSourceNode { silence, audioTimeStampPointer, frameCount, audioBufferList  in
        
        // get new lfos here if there are some to get
        // update lfos
        // lets callback to modulation manager and let it handle this
        
        let audioTimeStamp = audioTimeStampPointer.pointee
        
        if !self.hasStarted {
            self.startTime = audioTimeStamp.mSampleTime / self.sampleRate
            self.hasStarted = true
        }
        
        let realTime = audioTimeStamp.mSampleTime / self.sampleRate - self.startTime
        
        //DispatchQueue.main.async {
        for lfo in self.lfos {
            lfo.calculateNextLookupValue(realTime)
        }
        self.lookupsCompleteHandler()
        //}
        
        return noErr
    }
    
    /// Convenient way to get the node
    func getSourceNode() -> AVAudioSourceNode {
        return sourceNode
    }
    
    /// Convenient way to add a new LFO
    func addLFO(lfo: LFO) {
        lfos.append(lfo)
    }
    
}

/// Low frequency look up table oscillator
class LFO {
    
    /// Pattern the LFO will follow
    var table: Table
    
    /// Current value that will be read from LFO by modulation
    var lookupValue : Float64 = 0
    
    /// Rate of oscillation
    var frequency : Float {
        didSet {
            // this needs to only be set when we are not inside calulate next lookup value
            period = 1.0 / frequency
        }
    }
    
    /// Length of time for each oscillator
    var period : Float

    init(frequency: Float = 0.1, table: Table){
        self.frequency = frequency
        self.table = table
        self.period = 1/frequency
    }
    
    /// updates the LFO value from the lookup table based on the current time
    func calculateNextLookupValue(_ time: Float64) {

        // best to look at this value seperately as it is sometimes the cause of issues - when time gets too large things get weird
        let fMod = fmod(Float(time), period)
        
        // determine what value from table to use
        let xVal : Float = fMod * Float(table.count-1) * frequency
        
        if floor(xVal) == xVal {
            lookupValue = Float64(table.content[Int(xVal)])
        } else {
            // get values below and above the value
            let xFloor : Float = floor(xVal)
            let xCeil : Float = ceil(xVal)
            
            // linear interpolation between the two values of the table
            var newValue = table.content[Int(xFloor)] + (xVal - xCeil) * (table.content[Int(xCeil)] - table.content[Int(xFloor)]) / (xCeil - xFloor)
            
            // in case we get something outside 0-1
            if newValue > 1 {
                newValue = 1
            } else if newValue < 0 {
                newValue = 0
            }
            lookupValue = Float64(newValue)
        }
    }

}
