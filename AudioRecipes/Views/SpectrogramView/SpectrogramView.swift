import SwiftUI
import AudioKit

struct Queue {
    var items:[[CGPoint]] = []
    
    mutating func enqueue(element: [CGPoint]) {
        items.append(element)
    }
    mutating func dequeue() {
        if !items.isEmpty {
            items.remove(at: 0)
        }
    }
}

func createTestData() -> Queue{
    var queue = Queue()
    for _ in 0...79 {
        var points : [CGPoint] = []
        for i in 0..<SpectrogramModel.numberOfPoints {
            let frequency = 44100 * 0.5 * Double(i*2) / Double(2048)
            let amplitude = CGFloat(-200.0) //we should add a way to add randomized -200.0 to 0.0 data in order to have a preview
            points.append(CGPoint(x: CGFloat(frequency),y: amplitude))
        }
        queue.enqueue(element: points)
    }
    return queue
}

// MARK: SpectrogramModel
class SpectrogramModel: ObservableObject {
    static let numberOfPoints = 210 // TODO: remove this after creating empty queue
    
    // TODO: create an empty queue with a max number of items
    @Published var fftDataReadings = createTestData()
    
    var nodeTap: FFTTap!
    private var FFT_SIZE = 1024
    let sampleRate : double_t = 44100
    var node: Node?
    
    var minFreq = 30.0
    var maxFreq = 20000.0
    
    func updateNode(_ node: Node) {
        if node !== self.node {
            self.node = node
            nodeTap = FFTTap(node,bufferSize: UInt32(FFT_SIZE*2)) { fftData in
                DispatchQueue.main.async {
                    self.pushData(fftData)
                }
            }
            nodeTap.isNormalized = false
            nodeTap.zeroPaddingFactor = 1
            nodeTap.start()
        }
    }
    
    func pushData(_ fftFloats: [Float]) {
        // validate data
        // extra array necessary?
        var fftData = fftFloats
        for index in 0..<fftData.count {
            if fftData[index].isNaN { fftData[index] = 0.0 }
        }
        captureAmplitudeFrequencyData(fftData)
    }
    
    /// Returns frequency, amplitude pairs after removing unwanted data points (there are simply too many in the high frequencies)
    func captureAmplitudeFrequencyData(_ fftFloats: [Float]){
        
        // I don't love making these extra arrays
        let real = fftFloats.indices.compactMap{$0 % 2 == 0 ? fftFloats[$0] : nil }
        let imaginary = fftFloats.indices.compactMap{$0 % 2 != 0 ? fftFloats[$0] : nil }
        
        var maxSquared : Float = 0.0
        var frequencyChosen = 0.0

        var points: [CGPoint] = []
        
        for i in 0..<real.count {
            
            // I don't love doing this sort of calculation for every element
            let frequencyForBin = sampleRate * 0.5 * Double(i*2) / Double(real.count * 2)
            
            var squared = real[i] * real[i] + imaginary[i] * imaginary[i]
            
            if frequencyForBin > maxFreq {
                continue
            }
            
            if frequencyForBin > 10000 {
                if squared > maxSquared {
                    maxSquared = squared
                    frequencyChosen = frequencyForBin
                }
                if i % 8 != 0 {
                    // take the greatest 1 in every 8 points when > 10k Hz.
                    continue
                } else {
                    squared = maxSquared
                    maxSquared = 0.0
                }
            }
            else if frequencyForBin > 1000 {
                if squared > maxSquared {
                    maxSquared = squared
                    frequencyChosen = frequencyForBin
                }
                if i % 4 != 0 {
                    // take the greatest 1 in every 4 points when > 1k Hz.
                    continue
                } else {
                    squared = maxSquared
                    maxSquared = 0.0
                }
            } else {
                frequencyChosen = frequencyForBin
            }
            let amplitude = Double(10 * log10(4 * (squared)/(Float(FFT_SIZE) * Float(FFT_SIZE))))
            points.append(CGPoint(x: frequencyChosen, y: amplitude))
        }
        addFFTDataToQueue(points: points)
    }
    
    func addFFTDataToQueue(points: [CGPoint]) {
        fftDataReadings.dequeue()
        fftDataReadings.enqueue(element: points)
    }
}


struct SpectrogramView: View {
    @StateObject var spectrogram = SpectrogramModel()
    var node: Node
    
    var linearGradient : LinearGradient = LinearGradient(gradient: Gradient(colors: [.blue, .green, .yellow, .red]), startPoint: .bottom, endPoint: .top)
    @State var strokeColor : Color = Color.white.opacity(0.5)
    @State var fillColor : Color = Color.green.opacity(1.0)
    @State var backgroundColor: Color = Color.black
    
    var body: some View {
        
        let xOffset = CGFloat(0.24) / CGFloat(spectrogram.fftDataReadings.items.count)
        let yOffset = CGFloat(-0.84) / CGFloat(spectrogram.fftDataReadings.items.count)
        
        return GeometryReader { geometry in
            ZStack{
                backgroundColor
                .onAppear {
                    spectrogram.updateNode(node)
                }
                ForEach((0 ..< (spectrogram.fftDataReadings.items.count)).reversed(), id: \.self) { i in
                     Group{
                         createWave(width: geometry.size.width * 0.75, height: geometry.size.height * 0.2, points: spectrogram.fftDataReadings.items[spectrogram.fftDataReadings.items.count-i-1])
                                 .frame(width: geometry.size.width * 0.5,
                                        height: geometry.size.height * 0.2)
                            .offset(x: CGFloat(i) * geometry.size.width * xOffset - geometry.size.width/4.3,
                                    y: CGFloat(i) * geometry.size.height * yOffset + geometry.size.height/2.6)
                    }
                 }
            }.drawingGroup()
        }
    }
    
    func createWave(width: CGFloat, height: CGFloat, points: [CGPoint]) -> some View {
        var mappedPoints : [CGPoint] = []
        let startY = map(n: Double(points[0].y), start1: -200.0, stop1: 0.0, start2: Double(height), stop2: 0.0)
        mappedPoints.append(CGPoint(x: 0.0,y: startY))
        
        for i in 0..<points.count {
            let x = logMap(n: Double(points[i].x), start1: 30.0, stop1: 20_000, start2: 0.0, stop2: Double(width))
            var y = map(n: Double(points[i].y), start1: -200.0, stop1: 0.0, start2: Double(height), stop2: 0.0)
            if x > 0.0 {
                if y > Double(height) {
                    y = Double(height)
                }
                mappedPoints.append(CGPoint(x: x, y: y))
            }
        }
        
        mappedPoints.append(CGPoint(x: Double(width),y: Double(height)))
        mappedPoints.append(CGPoint(x: 0.0,y: Double(height)))
        
        return Path{ path in
            path.addLines(mappedPoints)
        }
        .fill(linearGradient)
    }
}

struct SpectrogramView_Previews: PreviewProvider {
    static var previews: some View {
        SpectrogramView(node: Mixer())
    }
}
