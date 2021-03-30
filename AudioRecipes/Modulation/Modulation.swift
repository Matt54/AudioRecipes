import Foundation
import AudioKit
import AVFoundation


// MARK: ParameterInfo
/// things we need to remember about a AUParameter
struct ParameterModulationInfo{
    var anchorValue : Float // basically just the starting AUParameter.value before we modulate it (think position a knob is pointing)
    var isLogRange : Bool
    var isBypassed : Bool
}

// MARK: ModulationManager
/// keeps track of many modulations - glue for the many to many relationship between modulations and AUParameters
final class ModulationManager : Node {
    
    fileprivate var lfoManager : LFOManager
    var anchorValueDictionary = [String: ParameterModulationInfo]()
    var modulations : [Modulation] = []
    var auParameters : [AUParameter] = []
    
    var newModulations : [Modulation] = []
    var isUpdating : Bool = false
    var canUpdate : Bool = false
    
    static let serialQueue = DispatchQueue(label: "modulation.serial.queue")
    static var modulationHandoffHandler: ((Modulation) -> Void) = { _ in }
    
    init(sampleRate: Double) {
        lfoManager = LFOManager(sampleRate: sampleRate)
        super.init(avAudioNode: lfoManager.getSourceNode())
        lfoManager.lookupsCompleteHandler = modulateMatrix
    }
    
    func createModulation(frequency: Float, table: Table, auParameter: AUParameter, isLogRange: Bool = false, magnitude: Float = 0, name: String = "") {
        ModulationManager.serialQueue.async {
            var modulationName = name
            if name == "" {
                modulationName = String(Modulation.modulationCount)
            }
            Modulation.modulationCount += 1
            
            let modulation = Modulation(frequency: frequency, table: table, name: modulationName)
            self.modulations.append(modulation)
            let lfo = modulation.getLFO()
            self.lfoManager.addLFO(lfo: lfo)
            self.addParameterToModulation(modulation: modulation, auParameter: auParameter)
            self.adjustMagnitudeForParameterModulation(modulation: modulation, auParameter: auParameter, newMagnitude: magnitude)
            ModulationManager.modulationHandoffHandler(modulation)
        }
    }
    
    func createModulation(frequency: Float, table: Table, auParameter: AUParameter, isLogRange: Bool = false, parameterValue: Float, name: String = "") {
        ModulationManager.serialQueue.async {
            var modulationName = name
            if name == "" {
                modulationName = String(Modulation.modulationCount)
            }
            Modulation.modulationCount += 1
            
            let modulation = Modulation(frequency: frequency, table: table, name: modulationName)
            self.modulations.append(modulation)
            let lfo = modulation.getLFO()
            self.lfoManager.addLFO(lfo: lfo)
            self.addParameterToModulation(modulation: modulation, auParameter: auParameter)
            self.setModulationMagnitudeToParameterValue(modulation: modulation, auParameter: auParameter, parameterValue: parameterValue)
            ModulationManager.modulationHandoffHandler(modulation)
        }
    }
    
    func createNewModulation(frequency: Float = 1, table: Table) {
        ModulationManager.serialQueue.async {
            let newModulation = Modulation(frequency: frequency, table: table)
            self.modulations.append(newModulation)
            let lfo = newModulation.getLFO()
            self.lfoManager.addLFO(lfo: lfo)
        }
    }
    
    func addParameterToModulation(modulation: Modulation, auParameter: AUParameter, isLogRange: Bool = false) {
        ModulationManager.serialQueue.async {
            modulation.addModulationTarget(auParameter: auParameter, isLogRange: isLogRange)
            //need to know if this is a parameter we haven't seen yet to hold the reference and anchor value
            if !self.auParameters.contains(auParameter) {
                self.auParameters.append(auParameter)
                let anchorValue = self.calculateRangeValueFromParameterValue(auParameter.value, min: auParameter.minValue, max: auParameter.maxValue, isLogRange: isLogRange)
                let parameterInfo = ParameterModulationInfo(anchorValue: anchorValue, isLogRange: isLogRange, isBypassed: false)
                self.anchorValueDictionary[auParameter.keyPath] = parameterInfo
            }
        }
    }
    
    func adjustMagnitudeForParameterModulation(modulation: Modulation, auParameter: AUParameter, newMagnitude: Float) {
        ModulationManager.serialQueue.async {
            if let mod = modulation.targets.first(where: {$0.auParameterKey == auParameter.keyPath}) {
                mod.modulationMagnitude = newMagnitude
            }
        }
    }
    
    func setModulationMagnitudeToParameterValue(modulation: Modulation, auParameter: AUParameter, parameterValue: Float){
        ModulationManager.serialQueue.async {
            if let modTarget = modulation.targets.first(where: {$0.auParameterKey == auParameter.keyPath}) {
                let rangeValue = self.calculateRangeValueFromParameterValue(parameterValue, min: auParameter.minValue, max: auParameter.maxValue, isLogRange: modTarget.isLogRange)
                if let parameterInfo = self.anchorValueDictionary[auParameter.keyPath] {
                    modTarget.modulationMagnitude = rangeValue - parameterInfo.anchorValue
                }
            }
        }
    }

    func addParameterToModulation(modulationIndex: Int, auParameter: AUParameter, isLogRange: Bool = false) {
        ModulationManager.serialQueue.async {
            let modulation = self.modulations[modulationIndex]
            modulation.addModulationTarget(auParameter: auParameter, isLogRange: isLogRange)
            //need to know if this is a parameter we haven't seen yet to hold the reference and anchor value
            if !self.auParameters.contains(auParameter) {
                self.auParameters.append(auParameter)
                let anchorValue = self.calculateRangeValueFromParameterValue(auParameter.value, min: auParameter.minValue, max: auParameter.maxValue, isLogRange: isLogRange)
                let parameterInfo = ParameterModulationInfo(anchorValue: anchorValue, isLogRange: isLogRange, isBypassed: false)
                self.anchorValueDictionary[auParameter.keyPath] = parameterInfo
            }
        }
    }
    
    func adjustMagnitudeForParameterModulation(modulationIndex: Int, auParameter: AUParameter, newMagnitude: Float) {
        ModulationManager.serialQueue.async {
            let modulation = self.modulations[modulationIndex]
            if let mod = modulation.targets.first(where: {$0.auParameterKey == auParameter.keyPath}) {
                mod.modulationMagnitude = newMagnitude
            }
        }
    }
    
    func setModulationMagnitudeToParameterValue(modulationIndex: Int, auParameter: AUParameter, parameterValue: Float){
        ModulationManager.serialQueue.async {
            let modulation = self.modulations[modulationIndex]
            if let modTarget = modulation.targets.first(where: {$0.auParameterKey == auParameter.keyPath}) {
                let rangeValue = self.calculateRangeValueFromParameterValue(parameterValue, min: auParameter.minValue, max: auParameter.maxValue, isLogRange: modTarget.isLogRange)
                if let parameterInfo = self.anchorValueDictionary[auParameter.keyPath] {
                    modTarget.modulationMagnitude = rangeValue - parameterInfo.anchorValue
                }
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
        ModulationManager.serialQueue.async {
            for auParameter in self.auParameters {
                let parameterInfo = self.anchorValueDictionary[auParameter.keyPath]!
                if !parameterInfo.isBypassed {
                    var modValue : Float = 0
                    for modulation in self.modulations {
                        if modulation.isCurrentlyRunning() {
                            modValue += modulation.getModifierValueForParameter(auParameterKey: auParameter.keyPath)
                        }
                    }
                    let rangeValue = parameterInfo.anchorValue + modValue
                    let parameterValue = self.calculateParameterValueFromRangeValue(rangeValue, min: auParameter.minValue, max: auParameter.maxValue, isLogRange: parameterInfo.isLogRange)
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
    }
}

// MARK: Modulation
/// A modulation takes an LFO value and applies it to one or more Modulation Targets (can be thought of as simply AUParameters - there's just some extra book keeping required)
final class Modulation : ObservableObject {
    
    static var modulationCount = 0
    var name: String
    var targets: [ModulationTarget] = []
    
    private var lfo : LFO
    
    private var isRunning : Bool = true
    @Published var isOn : Bool = true {
        didSet {
            // unsafe - needs to happen on modulation thread
            ModulationManager.serialQueue.async {
                self.isRunning = self.isOn
            }
        }
    }
    
    // safe to change modulation frequency from outside
    @Published var frequency : Float {
        didSet{
            
            // unsafe to change lfo frequency - needs to happen on modulation thread
            ModulationManager.serialQueue.async {
                self.lfo.frequency = self.frequency
            }
            
        }
    }
    
    init(frequency: Float, table: Table = Table.init(.positiveSawtooth)){
        lfo = LFO(frequency: frequency, table: table)
        self.frequency = frequency
        self.name = String(Modulation.modulationCount)
        Modulation.modulationCount += 1
    }
    
    init(frequency: Float, table: Table = Table.init(.positiveSawtooth), name: String){
        lfo = LFO(frequency: frequency, table: table)
        self.frequency = frequency
        self.name = name
        //Modulation.modulationCount += 1
    }

    func addModulationTarget(auParameter: AUParameter, isLogRange: Bool = false){
        let modulationTarget = ModulationTarget(auParameter: auParameter, isLogRange: isLogRange)
        targets.append(modulationTarget)
    }

    func getLFO() -> LFO {
        return lfo
    }
    
    func isCurrentlyRunning() -> Bool {
        return isRunning
    }
    
    func getModifierValueForParameter(auParameterKey: String) -> Float {
        if let modulationTarget = targets.first(where: {$0.auParameterKey == auParameterKey}){
            return modulationTarget.getModulationContribution(Float(lfo.lookupValue))
        } else {
            return 0
        }
    }
    
    // MARK: ModulationTarget
    final class ModulationTarget {
        /// 0 to 1.0 range
        /// anchorValue + modulationMagnitude must always be in a 0 to 1 range
        var anchorValue : Float
        
        /// -1.0 to 1.0 range
        /// anchorValue + modulationMagnitude must always be in a 0 to 1 range
        var modulationMagnitude : Float = 0
        
        /// must be known to determine the anchorValue
        var isLogRange : Bool
        
        var auParameterKey : String
        
        var isBypassed : Bool = false
        
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
            return isBypassed ? 0.0 : lookupValue * modulationMagnitude
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

// MARK: LFOManager
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
        
        let audioTimeStamp = audioTimeStampPointer.pointee
        
        if !self.hasStarted {
            self.startTime = audioTimeStamp.mSampleTime / self.sampleRate
            self.hasStarted = true
        }
        
        let realTime = audioTimeStamp.mSampleTime / self.sampleRate - self.startTime
        
        ModulationManager.serialQueue.async {
            for lfo in self.lfos {
                lfo.calculateNextLookupValue(realTime)
            }
            self.lookupsCompleteHandler()
        }
        
        return noErr
    }
    
    /// Convenient way to get the node
    func getSourceNode() -> AVAudioSourceNode {
        return sourceNode
    }
    
    /// Convenient way to add a new LFO
    func addLFO(lfo: LFO) {
        ModulationManager.serialQueue.async {
            self.lfos.append(lfo)
        }
    }
    
}

// MARK: LFO
/// Low frequency look up table oscillator
final class LFO {
    
    /// Pattern the LFO will follow
    var table: Table
    
    /// Current value that will be read from LFO by modulation
    var lookupValue : Float64 = 0
    
    /// In order to maintain the phase after the frequency changes, we zero the time and shift the phase
    private var phaseShift : Float = 0
    
    /// When a phase shift is applied after a frequency change, the time needs to be zero'd
    private var resetTime : Double = 0
    
    /// Need to remember the phase
    private var phase : Float = 0
    
    /// Need to remember the last time
    private var rememberTime : Double = 0
    
    /// Rate of oscillation
    var frequency : Float {
        didSet {
            period = 1.0 / frequency
            phaseShift = phase
            resetTime = rememberTime
        }
    }
    
    /// Length of time for each oscillator
    private var period : Float

    init(frequency: Float = 0.1, table: Table){
        self.frequency = frequency
        self.table = table
        self.period = 1/frequency
    }
    
    /// updates the LFO value from the lookup table based on the current time
    func calculateNextLookupValue(_ timeInput: Float64) {
        
        // do time keeping stuff
        rememberTime = timeInput
        let time = timeInput - resetTime

        // best to look at this value seperately as it is sometimes the cause of issues - when time gets too large things get weird
        let fMod = fmod(Float(time), period)
        
        phase = fmod(fMod * frequency + phaseShift, 1.0)
        
        // determine what value from table to use
        let xVal : Float = phase * Float(table.count-1)
        
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
