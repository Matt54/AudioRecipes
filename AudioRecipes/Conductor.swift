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
        let url = URL(fileURLWithPath: Bundle.main.resourcePath! + "/AnyKindOfWay.mp3")
        //let url = URL(fileURLWithPath: Bundle.main.resourcePath! + "/LittleThings.mp3")
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
        osc.frequency = 125
        silentMicMixer.volume = 0.0
        filter.cutoffFrequency = 20_000
        //filter.resonance = 10
        
        timer = RepeatingTimer(timeInterval: 0.008)
        timer.eventHandler = fire
        
        waveforms = createInterpolatedTables(inputTables: defaultWaves)
        calculateActualWaveTable(Int(wavePosition))
        setupAudioType()
        
        let wavetableURL = URL(fileURLWithPath: Bundle.main.resourcePath! + "/Sludgecrank.wav")
        let audioInformation = loadAudioSignal(audioURL: wavetableURL)
        let signal = audioInformation.signal
        let tables = chopAudioToTables(signal: signal)
        waveforms = createInterpolatedTables(inputTables: tables)
        
        timer.resume()
        //Timer.scheduledTimer(timeInterval: 0.002, target: self, selector: #selector(fire(timer:)), userInfo: [], repeats: true)

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
