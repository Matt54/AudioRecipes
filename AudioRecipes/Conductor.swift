import AudioKit
import AVFoundation
import Foundation
import Accelerate

class Conductor : ObservableObject{
    
    /// Single shared data model
    static let shared = Conductor()
    
    var testInputType : TestInputType = .player{
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
    
    var timer : RepeatingTimer
    
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
        player = createAudioPlayer(forResource: "AnyKindOfWay.mp3")
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
        osc.frequency = 125
        silentMicMixer.volume = 0.0
        filter.cutoffFrequency = 20_000
        //filter.resonance = 10
        
        timer = RepeatingTimer(timeInterval: 0.008)
        timer.eventHandler = fire

        waveforms = createWavetableArray(forResource: "Sludgecrank.wav")
        calculateActualWaveTable(Int(wavePosition))
        timer.resume()
        setupAudioType()
    }
    
    enum TestInputType {
        case microphone
        case oscillator
        case player
    }
    
    var timerReverse: Bool = false
    
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
            player.stop()
        } else if testInputType == .player {
            player.seek(time: 60.0)
            player.play()
            osc.stop()
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
