import AudioKit
import AVFoundation
import Foundation
import Accelerate

class Conductor : ObservableObject{
    
    /// Single shared data model
    static let shared = Conductor()
    
    var testInputType : TestInputType = .player {
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
    
    let filter : LowPassButterworthFilter
    
    /// limiter to prevent excessive volume at the output - just in case, it's the music producer in me :)
    let outputLimiter : PeakLimiter
    
    var file : AVAudioFile!
    
    var sampleRate : Double = AudioKit.Settings.sampleRate
    
    init(){
        
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
        let url = URL(fileURLWithPath: Bundle.main.resourcePath! + "/AnyKindOfWay.mp3")
        do{
            file = try AVAudioFile(forReading: url)
        } catch{
            print("oh no!")
        }
        player = AudioPlayer(file: file)!
        player.isLooping = true
        playerMixer = Mixer(player)
        
        // setup osc
        osc = DynamicOscillator()
        oscMixer = Mixer(osc)
        
        silentMicMixer = Mixer(micMixer)
        
        combinationMixer = Mixer(playerMixer)
        combinationMixer.addInput(silentMicMixer)
        combinationMixer.addInput(oscMixer)
        
        panner = Panner(combinationMixer)
        secondCombinationMixer = Mixer(panner)
        filter = LowPassButterworthFilter(secondCombinationMixer)
        
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
        
        osc.amplitude = 0.2
        osc.frequency = 500
        silentMicMixer.volume = 0.0
        filter.cutoffFrequency = 20_000
        //filter.resonance = 10
        
        waveforms = createInterpolatedTables(inputTables: defaultWaves)
        calculateActualWaveTable(Int(wavePosition))
        setupAudioType()
        
    }
    
    enum TestInputType {
        case microphone
        case oscillator
        case player
    }
    
    @Published var oscillatorFloats : [Float] = []
    
    /// actualWaveTable
    var actualWaveTable : Table!
    var displayWaveform : [Float] = []
    /// waveforms are the actual root wavetables that are used to calculate our current wavetable
    var waveforms : [Table] = []
    var displayWaveTables : [DisplayWaveTable] = []
    
    @Published var displayIndex: Int = 0
    let wavetableSize = 4096
    var defaultWaves : [Table] = [Table(.triangle), Table(.square), Table(.sine), Table(.sawtooth)] //[Table(.sine, count: 2048), Table(.sawtooth, count: 2048), Table(.square, count: 2048)]
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
        
        // calculate the new displayed wavetable
        displayWaveform = [Float](actualWaveTable.content)
        
    }
    
    func calculateAllWaveTables(){
        
        // 85 = 256 / 3
        let rangeValue = (Double(numberOfWavePositions) / Double(defaultWaves.count - 1)).rounded(.up)
        
        
        displayWaveTables = []
        waveforms = []
        
        let thresholdForExact = 0.01 * Double(defaultWaves.count)
        
        // 1 -> 256 (256 total)
        for i in 1...numberOfWavePositions{
            
            // this lets us grab the appropriate wavetables in an arbitrary array of tables
            
            // 0 = Int(37 / 85)
            // 1 = Int(90 / 85)
            // 2 = Int(170 / 85)
            let waveformIndex = Int( Double(i-1) / rangeValue) // % defaultWaves.count
            
            // 0.4118 = 35 / 85 % 1.0
            // 0.5882 = 135 / 85 % 1.0
            let interpolatedIndex = (Double(i-1) / rangeValue).truncatingRemainder(dividingBy: 1.0)
            
            if((1.0 - interpolatedIndex) < thresholdForExact){
                let tableElements = DisplayWaveTable([Float](defaultWaves[waveformIndex+1]))
                //displayWaveTables.append(tableElements)
                waveforms.append( Table(tableElements.waveform) )
            }
            else if(interpolatedIndex < thresholdForExact){
                let tableElements = DisplayWaveTable([Float](defaultWaves[waveformIndex]))
                //displayWaveTables.append(tableElements)
                waveforms.append( Table(tableElements.waveform) )
            }
            else{
                // calculate float values
                let tableElements = DisplayWaveTable([Float](vDSP.linearInterpolate([Float](defaultWaves[waveformIndex]),
                                                                            [Float](defaultWaves[waveformIndex+1]),
                                                                            using: Float(interpolatedIndex) ) ) )
                //displayWaveTables.append(tableElements)
                waveforms.append(Table(tableElements.waveform) )
            }
        }
    }
    
    /// A wrapper for a [Float]
    class DisplayWaveTable{
        var waveform : [Float]
        init(_ waveform: [Float]){
            self.waveform = waveform
        }
    }
    
    func createInterpolatedTables(inputTables: [Table], numberOfDesiredTables : Int = 256) -> [Table] {
        var interpolatedTables : [Table] = []
        let thresholdForExact = 0.01 * Double(inputTables.count)
        let rangeValue = (Double(numberOfDesiredTables) / Double(inputTables.count - 1)).rounded(.up)
        
        for i in 1...numberOfDesiredTables{
            let waveformIndex = Int( Double(i-1) / rangeValue)
            let interpolatedIndex = (Double(i-1) / rangeValue).truncatingRemainder(dividingBy: 1.0)
            
            // if we are nearly exactly at one of our input tables - use the input table for this index value
            if((1.0 - interpolatedIndex) < thresholdForExact){
                interpolatedTables.append(inputTables[waveformIndex+1])
            }
            else if(interpolatedIndex < thresholdForExact){
                interpolatedTables.append(inputTables[waveformIndex])
            }
            
            // between tables - interpolate
            else{
                // linear interpolate to get array of floats existing between the two tables
                let interpolatedFloats = [Float](vDSP.linearInterpolate([Float](inputTables[waveformIndex]),
                                                                            [Float](inputTables[waveformIndex+1]),
                                                                            using: Float(interpolatedIndex) ) )
                interpolatedTables.append(Table(interpolatedFloats))
            }
        }
        return interpolatedTables
    }
    
    func loadAudioSignal(audioURL: URL) -> (signal: [Float], rate: Double, frameCount: Int) {
        let file = try! AVAudioFile(forReading: audioURL)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: file.fileFormat.channelCount, interleaved: false)
        let buf = AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: UInt32(file.length))
        try! file.read(into: buf!) // You probably want better error handling
        let floatArray = Array(UnsafeBufferPointer(start: buf!.floatChannelData![0], count:Int(buf!.frameLength)))
        return (signal: floatArray, rate: file.fileFormat.sampleRate, frameCount: Int(file.length))
    }

    func setupAudioType(){
        if testInputType == .oscillator {
            osc.play()
            player.stop()
        } else if testInputType == .player {
            player.play()
            osc.stop()
        }
    }
    
}
