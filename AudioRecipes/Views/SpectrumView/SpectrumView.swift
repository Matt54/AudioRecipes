import AudioKit
import SwiftUI

// MARK: SpectrumModel
class SpectrumModel: ObservableObject {
    static let numberOfPoints = 256
    
    @Published var amplitudes: [CGFloat] = Array(repeating: 0.0, count: numberOfPoints)
    @Published var frequencies: [CGFloat] = Array(repeating: 0.0, count: numberOfPoints)
    
    var nodeTap: FFTTap!
    private var FFT_SIZE = 2048
    let sampleRate : double_t = 44100
    var node: Node?
    
    var minDeadBand: CGFloat = 40.0
    var maxDeadBand: CGFloat = 40.0
    var currentMidAmp: CGFloat = 100.0
    
    var minFreq = 30.0
    var maxFreq = 20000.0
    
    var minAmp: CGFloat = -1.0
    var maxAmp: CGFloat = -1_000.0
    var topAmp: CGFloat = -60.0
    var bottomAmp: CGFloat = -216.0
    var ampDisplacement: CGFloat = 120.0 / 2.0
    let maxSpan: CGFloat = 170
    
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
        determineAmplitudeBounds()
    }
    
    /// Returns frequency, amplitude pairs after removing unwanted data points (there are simply too many in the high frequencies)
    func captureAmplitudeFrequencyData(_ fftFloats: [Float]){
        
        // I don't love making these extra arrays
        let real = fftFloats.indices.compactMap{$0 % 2 == 0 ? fftFloats[$0] : nil }
        let imaginary = fftFloats.indices.compactMap{$0 % 2 != 0 ? fftFloats[$0] : nil }
        
        var maxSquared : Float = 0.0
        var frequencyChosen = 0.0
        
        var tempAmplitudes : [CGFloat] = []
        var tempFrequencies : [CGFloat] = []
        
        var minAmplitude = -1.0
        var maxAmplitude = -1_000.0
        
        for i in 0..<real.count {
            
            // I don't love doing this for every element
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
                if i % 16 != 0 {
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
                if i % 8 != 0 {
                    // take the greatest 1 in every 4 points when > 1k Hz.
                    continue
                } else {
                    squared = maxSquared
                    maxSquared = 0.0
                }
            }
            else {
                frequencyChosen = frequencyForBin
            }
            
            let amplitude = Double(10 * log10(4 * (squared)/(Float(FFT_SIZE) * Float(FFT_SIZE))))

            if amplitude > maxAmplitude {
                maxAmplitude = amplitude
            } else if amplitude < minAmplitude {
                minAmplitude = amplitude
            }
            
            tempAmplitudes.append(CGFloat(amplitude))
            tempFrequencies.append(CGFloat(frequencyChosen))
        }
        
        amplitudes = tempAmplitudes
        frequencies = tempFrequencies
        minAmp = CGFloat(minAmplitude)
        maxAmp = CGFloat(maxAmplitude)
    }
    
    /// Figures out what we should use for the maximum and minimum amplitudes displayed - also sets a "mid" amp which the dead band lies around
    func determineAmplitudeBounds(){
        if maxDeadBand < abs(maxAmp - currentMidAmp) ||  minDeadBand < abs(maxAmp - currentMidAmp) {
            // place us at a new location
            if abs(maxAmp) < ampDisplacement {
                currentMidAmp = -ampDisplacement
            } else {
                currentMidAmp = maxAmp
            }
            topAmp = currentMidAmp + ampDisplacement
            bottomAmp = currentMidAmp - ampDisplacement
            if bottomAmp > minAmp {
                if topAmp - minAmp > maxSpan {
                    bottomAmp = topAmp - maxSpan
                }
                else {
                    bottomAmp = minAmp
                }
            }
        }
        
    }

}

// MARK: SpectrumView
struct SpectrumView: View {
    @StateObject var spectrum = SpectrumModel()
    var node: Node
    
    @State var shouldPlotPoints: Bool = false
    @State var shouldStroke: Bool = true
    @State var shouldFill: Bool = true
    
    @State var backgroundColor: Color = Color.black
    @State var plotPointColor: Color = Color(red: 0.9, green: 0.9, blue: 0.9, opacity: 0.8)
    @State var strokeColor: Color = Color.white
    @State var fillColor: Color = Color(red: 0.5, green: 0.5, blue: 0.5, opacity: 0.4)
    @State var cursorColor = Color.white
    
    @State var frequencyDisplayed: Double = 100.0
    @State var amplitudeDisplayed: Double = -100.0
    
    @State var cursorX: Float = 0.0
    @State var cursorY: Float = 0.0
    @State var popupX: Float = 0.0
    @State var popupY: Float = 0.0
    @State var popupOpacity: Double = 0.0
    @State var cursorDisplayed: Bool = false
    
    @State var shouldAnalyzeTouch: Bool = true
    @State var shouldDisplayAxisLabels: Bool = true
    
    public var body: some View {
        GeometryReader{ geometry in
            createGraphView(width: geometry.size.width, height: geometry.size.height)
                .drawingGroup()
                .onAppear {
                    spectrum.updateNode(node)
                }
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            var x: Float = Float(value.location.x > geometry.size.width ? geometry.size.width : 0.0)
                            if value.location.x > 0.0 && value.location.x < geometry.size.width {
                                x = Float(value.location.x)
                            }
                            var y: Float = Float(value.location.y > geometry.size.height ? geometry.size.height : 0.0)
                            if value.location.y > 0.0 && value.location.y < geometry.size.height {
                                y = Float(value.location.y)
                            }
                            
                            cursorX = x
                            cursorY = y
                            
                            popupX = x > Float(geometry.size.width / 6) ? x - Float(geometry.size.width / 16) : x + Float(geometry.size.width / 16)
                            popupY = y > Float(geometry.size.height / 6) ? y - Float(geometry.size.width / 16) : y + Float(geometry.size.width / 16)
                            

                            frequencyDisplayed = Double(expMap(n: x, start1: Float(0.0), stop1: Float(geometry.size.width), start2: Float(spectrum.minFreq), stop2: Float(spectrum.maxFreq)))
                            amplitudeDisplayed = Double(map(n: CGFloat(y), start1: 0.0, stop1: geometry.size.height, start2: spectrum.topAmp, stop2: spectrum.bottomAmp))
                            
                            cursorDisplayed = true
                            popupOpacity = 1.0
                        }
                        .onEnded{_ in
                            popupOpacity = 0.0
                        }
                )
            
            if cursorDisplayed && shouldAnalyzeTouch {
                ZStack{
                    createCrossLines(width: geometry.size.width, height: geometry.size.height)
                    
                    CircleCursorView(cursorColor: cursorColor)
                        .frame(width: geometry.size.width / 30, height: geometry.size.height / 30)
                        .position(x: CGFloat(cursorX), y: CGFloat(cursorY))
                    
                    SpectrumPopupView(frequency: $frequencyDisplayed, amplitude: $amplitudeDisplayed, colorForeground: cursorColor)
                        .overlay(
                                RoundedCorner(radius: 10.0, corners: [.allCorners])
                                     .stroke(cursorColor)
                                     .shadow(color: cursorColor, radius: 3, x: 0, y: 0)
                        )
                        .position(x: CGFloat(popupX), y: CGFloat(popupY))
                }
                .opacity(popupOpacity)
                .animation(.default)
                .drawingGroup()
            }
        }
    }
    
    private func createCrossLines(width: CGFloat, height: CGFloat) -> some View {
        var horizontalPoints : [CGPoint] = []
        horizontalPoints.append(CGPoint(x: 0.0,y: Double(cursorY)))
        horizontalPoints.append(CGPoint(x: Double(width),y: Double(cursorY)))
        
        var verticalPoints : [CGPoint] = []
        verticalPoints.append(CGPoint(x: Double(cursorX),y: 0.0))
        verticalPoints.append(CGPoint(x: Double(cursorX),y: Double(height)))
        return ZStack{
            Path{ path in
                path.addLines(horizontalPoints)
            }
            .stroke(strokeColor,lineWidth: 2).opacity(0.7)
            Path{ path in
                path.addLines(verticalPoints)
            }
            .stroke(strokeColor,lineWidth: 2).opacity(0.7)
        }
    }
    
    private func createGraphView(width: CGFloat, height: CGFloat) -> some View {
        return ZStack{
            backgroundColor

            if shouldPlotPoints {
                createSpectrumCircles(width: width, height: height)
            }
            
            if shouldStroke || shouldFill {
                createSpectrumShape(width: width, height: height)
            }
            
            HorizontalAxis(minX: spectrum.minFreq, maxX: spectrum.maxFreq, isLogarithmicScale: true, shouldDisplayAxisLabel: shouldDisplayAxisLabels)
            VerticalAxis(minY: $spectrum.bottomAmp, maxY: $spectrum.topAmp, shouldDisplayAxisLabel: shouldDisplayAxisLabels)
        }
    }
    
    func createSpectrumCircles(width: CGFloat, height: CGFloat) -> some View {
        
        var mappedPoints = Array(repeating: CGPoint(x: 0.0, y: 0.0), count: SpectrumModel.numberOfPoints)
        
        // I imagine this is not good computationally
        for i in 0..<spectrum.amplitudes.count {
            let mappedAmplitude = map(n: Double(spectrum.amplitudes[i]), start1: Double(spectrum.bottomAmp), stop1: Double(spectrum.topAmp), start2: 1.0, stop2: 0.0)
            let mappedFrequency = logMap(n: Double(spectrum.frequencies[i]), start1: spectrum.minFreq, stop1: spectrum.maxFreq, start2: 0.0, stop2: 1.0)
            mappedPoints[i] = CGPoint(x: mappedFrequency, y: mappedAmplitude)
        }
        
        return ZStack{
            ForEach(1 ..< mappedPoints.count) {
                if(mappedPoints[$0].x > 0.00001){
                    Circle()
                        .fill(plotPointColor)
                        .frame(width: width * 0.005)
                        .position(CGPoint(x: mappedPoints[$0].x * width, y: mappedPoints[$0].y * height))
                        .animation(.easeInOut(duration: 0.1))
                }
            }
        }
    }
    
    func createSpectrumShape(width: CGFloat, height: CGFloat) -> some View {
        
        var mappedPoints = Array(repeating: CGPoint(x: 0.0, y: 0.0), count: SpectrumModel.numberOfPoints)
        var mappedIndexedDoubles: [Double] = Array(repeating: 0.0, count: SpectrumModel.numberOfPoints*2 + 4)
        
        // I imagine this is not good computationally
        for i in 0..<spectrum.amplitudes.count {
            let mappedAmplitude = map(n: Double(spectrum.amplitudes[i]), start1: Double(spectrum.bottomAmp), stop1: Double(spectrum.topAmp), start2: 1.0, stop2: 0.0)
            let mappedFrequency = logMap(n: Double(spectrum.frequencies[i]), start1: spectrum.minFreq, stop1: spectrum.maxFreq, start2: 0.0, stop2: 1.0)
            mappedPoints[i] = CGPoint(x: mappedFrequency, y: mappedAmplitude)
            
            if mappedFrequency > 0.0 && mappedFrequency < 1.0{
                mappedIndexedDoubles[2*i] = mappedFrequency
            }
            mappedIndexedDoubles[2*i+1] = mappedAmplitude
        }
        
        mappedIndexedDoubles[SpectrumModel.numberOfPoints*2 - 4] = 1.0
        mappedIndexedDoubles[SpectrumModel.numberOfPoints*2 - 3] = 1.0
        mappedIndexedDoubles[SpectrumModel.numberOfPoints*2 - 2] = 0.0
        mappedIndexedDoubles[SpectrumModel.numberOfPoints*2 - 1] = 1.0
        
        return ZStack{
            if shouldStroke {
                MorphableShape(controlPoints: AnimatableVector(with: mappedIndexedDoubles))
                    .stroke(strokeColor, style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                    .animation(.easeInOut(duration: 0.1))
            }
            
            if shouldFill {
                MorphableShape(controlPoints: AnimatableVector(with: mappedIndexedDoubles))
                    .fill(fillColor)
                    .animation(.easeInOut(duration: 0.1))
            }
        }
    }
}

func map(n: Double, start1: Double, stop1: Double, start2: Double, stop2: Double) -> Double {
    return ((n - start1) / (stop1 - start1)) * (stop2 - start2) + start2
}

func map(n: CGFloat, start1: CGFloat, stop1: CGFloat, start2: CGFloat, stop2: CGFloat) -> CGFloat {
    return ((n - start1) / (stop1 - start1)) * (stop2 - start2) + start2
}

func logMap(n: Double, start1: Double, stop1: Double, start2: Double, stop2: Double) -> Double {
    let logN = log10(n)
    let logStart1 = log10(start1)
    let logStop1 = log10(stop1)
    let result = ((logN - logStart1 ) / (logStop1 - logStart1)) * (stop2 - start2) + start2
    if(result.isNaN){
        return 0.1
    } else {
        return ((logN - logStart1 ) / (logStop1 - logStart1)) * (stop2 - start2) + start2
    }
}

func expMap(n: Float, start1: Float, stop1: Float, start2: Float, stop2: Float) -> Float {

    let logStart2 = log(start2);
    let logStop2 = log(stop2);

    // calculate adjustment factor
    let scale = (logStop2-logStart2) / Float(stop1-start1);

    return exp(logStart2 + scale*(Float(n)-start1));
}

// This packages the y locations in a convenient way for the MorphableShape struct
struct HorizontalLineData{
    let locationData : [Double]
    
    init(yLoc: Double){
        locationData = [0.0, yLoc, 1.0, yLoc]
    }
}

func calculateLocalCoordinateFraction(point: CGPoint, width: CGFloat, height: CGFloat) -> CGPoint {
    return CGPoint(x: map(n: point.x, start1: 0.0, stop1: width, start2: 0.0, stop2: 1.0)
                        , y: map(n: point.y, start1: 0.0, stop1: height, start2: 0.0, stop2: 1.0))
}

// MARK: HorizontalAxis
struct HorizontalAxis: View {
    
    @State var minX : Double = 30
    @State var maxX : Double = 20_000
    @State var isLogarithmicScale: Bool = true
    @State var shouldDisplayAxisLabel: Bool = true
    
    public var body: some View {
        
        let verticalLineXLocations = [100.0,1000.0,10000.0]
        let verticalLineLabels = ["100","1k","10k"]
        
        var verticalLineXLocationsMapped : [CGFloat] = Array(repeating: 0.0, count: verticalLineXLocations.count)
        
        if isLogarithmicScale {
            for i in 0..<verticalLineXLocations.count {
                verticalLineXLocationsMapped[i] = CGFloat(logMap(n: verticalLineXLocations[i], start1: minX, stop1: maxX, start2: 0.0, stop2: 1.0))
            }
        } else {
            for i in 0..<verticalLineXLocations.count {
                verticalLineXLocationsMapped[i] = CGFloat(map(n: verticalLineXLocations[i], start1: minX, stop1: maxX, start2: 0.0, stop2: 1.0))
            }
        }
        
        return ZStack{
            GeometryReader{ geo in
                ForEach(0 ..< verticalLineXLocationsMapped.count) {i in
                    Path{ path in
                        path.move(to: CGPoint(x: verticalLineXLocationsMapped[i] * geo.size.width, y: 0.0))
                        path.addLine(to: CGPoint(x: verticalLineXLocationsMapped[i] * geo.size.width, y: geo.size.height))
                    }
                    .stroke(Color(red: 0.9, green: 0.9, blue: 0.9, opacity: 0.8))

                    if shouldDisplayAxisLabel {
                        Text(verticalLineLabels[i])
                            .font(.footnote)
                            .foregroundColor(.white)
                            .position(x: verticalLineXLocationsMapped[i] * geo.size.width + geo.size.width * 0.02, y: geo.size.height * 0.03)
                    }
                }
            }
        }
    }
}

// MARK: VerticalAxis
struct VerticalAxis: View {
    
    @Binding var minY : CGFloat
    @Binding var maxY : CGFloat
    @State var shouldDisplayAxisLabel: Bool = true
    
    public var body: some View {
        
        var horizontalLineYLocations: [CGFloat] = []
        for i in 1...20 {
            let amp : CGFloat = CGFloat(i) * -12.0
            if i % 2 != 0 {
                horizontalLineYLocations.append(amp)
            }
        }
        
        var horizontalLineYLocationsMapped:[CGFloat] = Array(repeating: 0.0, count: horizontalLineYLocations.count)
        var locationData : [HorizontalLineData] = []
        
        for i in 0..<horizontalLineYLocations.count {
            horizontalLineYLocationsMapped[i] = map(n: horizontalLineYLocations[i], start1: minY, stop1: maxY, start2: 1.0, stop2: 0.0)
            locationData.append(HorizontalLineData(yLoc: Double(horizontalLineYLocationsMapped[i])))
        }
        
        return ZStack{
            GeometryReader{ geo in
                ForEach(0 ..< horizontalLineYLocationsMapped.count) {i in
                    if horizontalLineYLocationsMapped[i] > 0.0 && horizontalLineYLocationsMapped[i] < 1.0 {
                        
                        MorphableShape(controlPoints: AnimatableVector(with: locationData[i].locationData))
                            .stroke(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.4))
                            .animation(.easeInOut(duration: 0.2))
                        
                        if shouldDisplayAxisLabel {
                            let labelString = String(Int(horizontalLineYLocations[i]))
                            Text(labelString)
                                .position(x: geo.size.width * 0.03, y: horizontalLineYLocationsMapped[i] * geo.size.height - geo.size.height * 0.03)
                                .animation(.easeInOut(duration: 0.2))
                                .font(.footnote)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
    }
    
    // This packages the y locations in a convenient way for the MorphableShape struct
    struct HorizontalLineData{
        let locationData : [Double]
        
        init(yLoc: Double){
            locationData = [0.0, yLoc, 1.0, yLoc]
        }
    }
    
}

// MARK: SpectrumView_Previews
struct SpectrumView_Previews: PreviewProvider {
    static var previews: some View {
        SpectrumView(node: Mixer())
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
     }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect,
            byRoundingCorners: corners, cornerRadii: CGSize(width:
            radius, height: radius))
        return Path(path.cgPath)
    }
}
