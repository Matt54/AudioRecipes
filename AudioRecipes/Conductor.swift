import AudioKit
import AVFoundation
import Foundation
import Accelerate

class Conductor : ObservableObject{
    
    /// Single shared data model
    static let shared = Conductor()
    
    var testInputType : TestInputType = .oscillator{
        didSet{
            setupAudioType()
        }
    }
    
    /// Audio engine instance
    let engine = AudioEngine()
        
    /// default microphone
    var mic: AudioEngine.InputNode
    /// mixing node for microphone input - routes to plotting and recording paths
    let micMixer : Mixer
    /// mixer with no volume so that we don't output audio
    let silentMicMixer : Mixer
    
    var noise : WhiteNoise
    let noiseMixer: Mixer
    
    var osc: DynamicOscillator
    let oscMixer: Mixer
    
    @Published var pan = 0.0 {
        didSet {
            panner.pan = AUValue(pan)
        }
    }
    let panner: Panner
    
    var player: AudioPlayer
    let playerMixer: Mixer
    
    /// Audio chain converges on this mixer
    let combinationMixer : Mixer
    
    let secondCombinationMixer : Mixer
    
    let filter : LowPassFilter
    
    /// limiter to prevent excessive volume at the output - just in case, it's the music producer in me :)
    let outputLimiter : PeakLimiter
    
    var file : AVAudioFile!
    
    var sampleRate : Double = AudioKit.Settings.sampleRate
    
    //var timer : RepeatingTimer
    
    var modulationManager : ModulationManager
    
    //var modulation : ModulationPOC
    

    init(){
        
        //modulation = ModulationPOC(frequency: 0.1, table: Table.init(.positiveSine))
        
        
        do{
            try AudioKit.Settings.session.setCategory(.playAndRecord, options: .defaultToSpeaker)
        } catch{
            assert(false, error.localizedDescription)
        }
        
        guard let input = engine.input else {
            fatalError()
        }
        
        
        
        // setup mic
        mic = input
        micMixer = Mixer(mic)
        
        // setup player
        player = createAudioPlayer(forResource: "AnyKindOfWay.mp3")
        player.isLooping = true
        playerMixer = Mixer(player)
      
        // setup osc
        osc = DynamicOscillator()
        oscMixer = Mixer(osc)
        
        noise = WhiteNoise()
        noiseMixer = Mixer(noise)
        
        silentMicMixer = Mixer(micMixer)
        
        combinationMixer = Mixer(playerMixer)
        combinationMixer.addInput(silentMicMixer)
        combinationMixer.addInput(oscMixer)
        combinationMixer.addInput(noiseMixer)
        
        panner = Panner(combinationMixer)
        secondCombinationMixer = Mixer(panner)
        filter = LowPassFilter(secondCombinationMixer)
        
        // route the silent Mixer to the limiter (you must always route the audio chain to AudioKit.output)
        outputLimiter = PeakLimiter(filter)
        
        // set the limiter as the last node in our audio chain
        engine.output = outputLimiter
        
        //START AUDIOKIT
        do{
            try engine.start()
            filter.start()
        }
        catch{
            assert(false, error.localizedDescription)
        }
        
        let audioEngine = engine.avEngine
        let outputNode = audioEngine.outputNode
        let format = outputNode.inputFormat(forBus: 0)
        
        sampleRate = format.sampleRate
        modulationManager = ModulationManager(sampleRate: sampleRate)
        
        
        
        //combinationMixer.addInput(modulation)
        
        osc.amplitude = 0.2
        osc.frequency = 100
        silentMicMixer.volume = 0.0
        filter.cutoffFrequency = 10_000
        filter.resonance = 10
        
        //timer = RepeatingTimer(timeInterval: 0.002)
        
        //timer.eventHandler = fire

        waveforms = createWavetableArray(forResource: "Sludgecrank.wav")
        calculateActualWaveTable(Int(wavePosition))
        //timer.resume()
        setupAudioType()
        
        //modulation.modulationCallback = modulationUpdate
        //filter.cutoffFrequency = 0 //18_000
        
        setupFilterModulation()
        
        osc.amplitude = 0.1
        //noise.amplitude = 1.0
        setupAmplitudeModulation(osc)
        //outputLimiter.preGain = -10
        //setupLimiterGainModulation(node: outputLimiter)
        //printAllParameters(osc)
        printAllParameters(outputLimiter)
        
        combinationMixer.addInput(modulationManager)
        
        setupFrequencyModulation(osc)
    }
    
    enum TestInputType {
        case microphone
        case oscillator
        case player
        case noise
    }
    
    var timerReverse: Bool = false
    
    func printAllParameters(_ node: Node){
        let auAudioUnit = node.avAudioUnitOrNode.auAudioUnit
        guard let paramTree = auAudioUnit.parameterTree else { return }
        for parameter in paramTree.allParameters {
            print(parameter.keyPath)
            print(parameter.identifier)
            print(parameter.value)
            print(parameter.minValue)
            print(parameter.maxValue)
            print(parameter.unitName!)
        }
    }
    
    func changeFrequencyOfNodeParameter(_ node: Node) {
        let auAudioUnit = osc.avAudioUnitOrNode.auAudioUnit
        //auAudioUnit.
    }
    
    func changeFrequencyOfOscillatorNodeByParameter(_ osc: Oscillator) {
        let auAudioUnit = osc.avAudioUnitOrNode.auAudioUnit
    }
    
    func setupFrequencyModulation(_ node: Node) {
        let auAudioUnit = node.avAudioUnitOrNode.auAudioUnit
        guard let paramTree = auAudioUnit.parameterTree else { return }
        
        // Not proud of this block - there's gotta be a clean approach to this
        var frequencyOptional :AUParameter?
        for parameter in paramTree.allParameters {
            if parameter.identifier == "frequency" {
                frequencyOptional = parameter
            }
        }
        guard let frequency = frequencyOptional else { return }
        print(frequency.value)
        print(frequency.minValue)
        print(frequency.maxValue)
        let mod = modulationManager.createNewModulation(frequency: 2, table: Table.init(.positiveSine))
        modulationManager.addParameterToModulation(modulation: mod, auParameter: frequency, isLogRange: true)
        modulationManager.setModulationMagnitudeToParameterValue(modulation: mod, auParameter: frequency, parameterValue: 500)
    }
    
    func setupAmplitudeModulation(_ node: Node) {
        let auAudioUnit = node.avAudioUnitOrNode.auAudioUnit
        guard let paramTree = auAudioUnit.parameterTree else { return }
        
        // Not proud of this block - there's gotta be a clean approach to this
        var frequencyOptional :AUParameter?
        for parameter in paramTree.allParameters {
            if parameter.identifier == "amplitude" {
                frequencyOptional = parameter
            }
        }
        guard let frequency = frequencyOptional else { return }
        print(frequency.value)
        print(frequency.minValue)
        print(frequency.maxValue)
        let mod = modulationManager.createNewModulation(frequency: 8, table: Table.init(.positiveSquare))
        modulationManager.addParameterToModulation(modulation: mod, auParameter: frequency, isLogRange: false)
        modulationManager.setModulationMagnitudeToParameterValue(modulation: mod, auParameter: frequency, parameterValue: 1)
    }
    
    func setupFilterModulation() {

        let node = filter
        
        let auAudioUnit = node.avAudioUnitOrNode.auAudioUnit
        guard let paramTree = auAudioUnit.parameterTree else { return }
        
        // Not proud of this block - there's gotta be a clean approach to this
        var cutoffOptional :AUParameter?
        var resonanceOptional: AUParameter?
        for parameter in paramTree.allParameters {
            if parameter.identifier == "0" { // I want to look for a 'cutoff'
                cutoffOptional = parameter
            } else if parameter.identifier == "1" { // and 'resonance'
                resonanceOptional = parameter
            }
        }
        guard let cutoff = cutoffOptional else { return }
        guard let resonance = resonanceOptional else { return }
        
        let mod = modulationManager.createNewModulation(frequency: 1, table: Table.init(.positiveSine))
        modulationManager.addParameterToModulation(modulation: mod, auParameter: cutoff, isLogRange: true)
        modulationManager.setModulationMagnitudeToParameterValue(modulation: mod, auParameter: cutoff, parameterValue: 750)
        
        let mod2 = modulationManager.createNewModulation(frequency: 2, table: Table.init(.positiveSine))
        modulationManager.addParameterToModulation(modulation: mod2, auParameter: cutoff, isLogRange: true)
        modulationManager.adjustMagnitudeForParameterModulation(modulation: mod2, auParameter: cutoff, newMagnitude: -0.1)
        
        modulationManager.addParameterToModulation(modulation: mod2, auParameter: resonance)
        modulationManager.adjustMagnitudeForParameterModulation(modulation: mod2, auParameter: resonance, newMagnitude: 0.1)

        //let modulationTarget = modulation.addModulationTarget(auParameter: cutoff, startValue: 20_000, endValue: 1000, isLogRange: true)
        //modulationTarget.setMagnitudeByParameterValue(100)
        //modulationTarget
    }
    
    func setupLimiterGainModulation(node: Node) {
        
        let auAudioUnit = node.avAudioUnitOrNode.auAudioUnit
        guard let paramTree = auAudioUnit.parameterTree else { return }
        
        // Not proud of this block - there's gotta be a clean approach to this
        var gainOptional :AUParameter?
        for parameter in paramTree.allParameters {
            if parameter.identifier == "2" { // I want to look for a 'cutoff'
                gainOptional = parameter
            }
        }
        guard let gain = gainOptional else { return }
        
        let mod = modulationManager.createNewModulation(frequency: 1, table: Table.init(.positiveSine))
        modulationManager.addParameterToModulation(modulation: mod, auParameter: gain)
        modulationManager.setModulationMagnitudeToParameterValue(modulation: mod, auParameter: gain, parameterValue: 10)
    }
    
    func modulationUpdate(_ newValue: Float64) {
        DispatchQueue.main.async {
            //do something
            var newIndex = newValue * Double(self.waveforms.count)
            
            if newIndex < 0 {
                newIndex = 0
            } else if Int(newIndex) > self.waveforms.count-1 {
                newIndex = Double(self.waveforms.count-1)
            }
            
            self.wavePosition = newIndex
            
            /*if !self.timerReverse{
                if Int(self.wavePosition) >= self.numberOfWavePositions-1 {
                    self.timerReverse.toggle()
                } else {
                    self.wavePosition += 1
                }
            } else {
                if Int(self.wavePosition) <= 0 {
                    self.timerReverse.toggle()
                } else {
                    self.wavePosition -= 1
                }
            }*/
        }
    }
    
    @objc func fire()
    {
        DispatchQueue.main.async {
            //do something
            if !self.timerReverse{
                if Int(self.wavePosition) >= self.numberOfWavePositions-1 {
                    self.timerReverse.toggle()
                } else {
                    self.wavePosition += 1
                }
            } else {
                if Int(self.wavePosition) <= 0 {
                    self.timerReverse.toggle()
                } else {
                    self.wavePosition -= 1
                }
            }
        }
    }
    
    @Published var oscillatorFloats : [Float] = []
    
    /// actualWaveTable
    var actualWaveTable : Table!

    /// waveforms are the actual root wavetables that are used to calculate our current wavetable
    var waveforms : [Table] = []

    let wavetableSize = 512
    //var defaultWaves : [Table] = [Table(.triangle, count: 256), Table(.square, count: 256), Table(.sine, count: 256), Table(.sawtooth, count: 256)]
    
    var defaultWaves : [Table] = [Table(.triangle), Table(.square), Table(.sine), Table(.sawtooth)]
    //[Table(.sine, count: 2048), Table(.sawtooth, count: 2048), Table(.square, count: 2048)]
    var numberOfWavePositions = 256
    
    var wavePosition: Double = 0.0{
        didSet{
            calculateActualWaveTable(Int(wavePosition))
            oscillatorFloats = osc.getWavetableValues()
        }
    }
    
    /// This is called whenever we have an waveTable index or warp change to create a new waveTable
    func calculateActualWaveTable(_ wavePosition: Int) {

        // set the actualWaveTable to the new floating point values
        actualWaveTable = waveforms[wavePosition]

        // call to switch the wavetable
        osc.setWaveTable(waveform: actualWaveTable)
        
    }

    func setupAudioType(){
        if testInputType == .oscillator {
            osc.play()
            noise.stop()
            player.stop()
        } else if testInputType == .player {
            player.seek(time: 60.0)
            player.play()
            osc.stop()
        } else if testInputType == .noise {
            osc.stop()
            noise.play()
            player.stop()
        }
    }
}

func createAudioPlayer(forResource: String) -> AudioPlayer {
    let path = Bundle.main.path(forResource: forResource, ofType: nil)!
    let url = URL(fileURLWithPath: path)
    if let file = try? AVAudioFile(forReading: url) {
        if let player = AudioPlayer(file: file) {return player}
    }
    print("Could not load resource: \(forResource)")
    return AudioPlayer()
}

func createWavetableArray(forResource: String) -> [Table] {
    let path = Bundle.main.path(forResource: forResource, ofType: nil)!
    let url = URL(fileURLWithPath: path)
    let audioInformation = loadAudioSignal(audioURL: url)
    let signal = audioInformation.signal
    let tables = chopAudioToTables(signal: signal)
    return createInterpolatedTables(inputTables: tables)
}
