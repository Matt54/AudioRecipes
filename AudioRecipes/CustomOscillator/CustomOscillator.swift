import AVFoundation
import CAudioKit
import AudioKit

/// Reads from the table sequentially and repeatedly at given frequency.
/// Linear interpolation is applied for table look up from internal phase values.
///
public class CustomOscillator: Node, AudioUnitContainer, Toggleable {

    /// Unique four-letter identifier "csto"
    public static let ComponentDescription = AudioComponentDescription(generator: "csto")

    /// Internal type of audio unit for this node
    public typealias AudioUnitType = InternalAU

    /// Internal audio unit
    public private(set) var internalAU: AudioUnitType?

    // MARK: - Parameters
    
    fileprivate var waveform: Table?

    /// Specification details for frequency
    public static let frequencyDef = NodeParameterDef(
        identifier: "frequency",
        name: "Frequency (Hz)",
        address: akGetParameterAddress("CustomOscillatorParameterFrequency"),
        range: 0.0 ... 20_000.0,
        unit: .hertz,
        flags: .default)

    /// Frequency in cycles per second
    @Parameter public var frequency: AUValue

    /// Specification details for amplitude
    public static let amplitudeDef = NodeParameterDef(
        identifier: "amplitude",
        name: "Amplitude",
        address: akGetParameterAddress("CustomOscillatorParameterAmplitude"),
        range: 0.0 ... 10.0,
        unit: .generic,
        flags: .default)

    /// Output Amplitude.
    @Parameter public var amplitude: AUValue

    /// Specification details for detuningOffset
    public static let detuningOffsetDef = NodeParameterDef(
        identifier: "detuningOffset",
        name: "Frequency offset (Hz)",
        address: akGetParameterAddress("CustomOscillatorParameterDetuningOffset"),
        range: -1_000.0 ... 1_000.0,
        unit: .hertz,
        flags: .default)

    /// Frequency offset in Hz.
    @Parameter public var detuningOffset: AUValue

    /// Specification details for detuningMultiplier
    public static let detuningMultiplierDef = NodeParameterDef(
        identifier: "detuningMultiplier",
        name: "Frequency detuning multiplier",
        address: akGetParameterAddress("CustomOscillatorParameterDetuningMultiplier"),
        range: 0.9 ... 1.11,
        unit: .generic,
        flags: .default)

    /// Frequency detuning multiplier
    @Parameter public var detuningMultiplier: AUValue

    // MARK: - Audio Unit

    /// Internal Audio Unit for CustomOscillator
    public class InternalAU: AudioUnitBase {
        /// Get an array of the parameter definitions
        /// - Returns: Array of parameter definitions
        public override func getParameterDefs() -> [NodeParameterDef] {
            [CustomOscillator.frequencyDef,
             CustomOscillator.amplitudeDef,
             CustomOscillator.detuningOffsetDef,
             CustomOscillator.detuningMultiplierDef]
        }

        /// Create the DSP Refence for this node
        /// - Returns: DSP Reference (Pointer to an instance of an DSPBase subclass)
        public override func createDSP() -> DSPRef {
            akCreateDSP("CustomOscillatorDSP")
        }
    }

    // MARK: - Initialization

    /// Initialize this CustomOscillator node
    ///
    /// - Parameters:
    ///   - waveform: The waveform of oscillation
    ///   - frequency: Frequency in cycles per second
    ///   - tremoloFrequency: Tremolo frequency in cycles per second
    ///   - amplitude: Output Amplitude.
    ///   - detuningOffset: Frequency offset in Hz.
    ///   - detuningMultiplier: Frequency detuning multiplier
    ///
    public init(
        waveform: Table = Table(.sawtooth),
        frequency: AUValue = 440.0,
        tremoloFrequency: AUValue = 1.0,
        amplitude: AUValue = 1.0,
        detuningOffset: AUValue = 0.0,
        detuningMultiplier: AUValue = 1.0
    ) {
        super.init(avAudioNode: AVAudioNode())

        instantiateAudioUnit { avAudioUnit in
            self.avAudioUnit = avAudioUnit
            self.avAudioNode = avAudioUnit

            guard let audioUnit = avAudioUnit.auAudioUnit as? AudioUnitType else {
                fatalError("Couldn't create audio unit")
            }
            self.internalAU = audioUnit
            self.stop()
            audioUnit.setWavetable(waveform.content)

            self.waveform = waveform
            self.frequency = frequency
            self.amplitude = amplitude
            self.detuningOffset = detuningOffset
            self.detuningMultiplier = detuningMultiplier
        }
    }
    
    public func setWaveTable(waveform: Table){
        self.internalAU!.setWavetable(waveform.content)
    }
    
}
