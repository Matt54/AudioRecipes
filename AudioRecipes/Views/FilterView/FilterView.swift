import AudioKit
import SwiftUI
import AVFoundation
import Accelerate


class FilterModel: ObservableObject {
    var node: LowPassFilter?
    var cutoffLoopBlock = false
    
    @Published var cutoff : Double = 6_900.0
    @Published var resonance: Double = 1.0
    
    var minFreq = 30.0
    var maxFreq = 20000.0
    
    func updateNode(_ node: LowPassFilter) {
        if node !== self.node {
            self.node = node
            
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
            
            
            self.cutoff = Double(cutoff.value)
            self.resonance = Double(resonance.value)
            
            // Observe value changes made to the cutoff and resonance parameters.
            let parameterObserverToken =
                paramTree.token(byAddingParameterObserver: { [weak self] address, value in
                    guard let self = self else { return }

                    // This closure is being called by an arbitrary queue. Ensure
                    // all UI updates are dispatched back to the main thread.
                    if [cutoff.address, resonance.address].contains(address) {
                        DispatchQueue.main.async {
                            self.cutoff = Double(cutoff.value)
                            self.resonance = Double(resonance.value)
                        }
                    }
                })
        }
    }
}

struct FilterView: View {
    @StateObject var filterModel = FilterModel()
    var node: LowPassFilter
    
    @State var strokeColor: Color = Color.yellow
    @State var fillColor: Color = Color(red: 0.7, green: 0.7, blue: 0.5, opacity: 0.8)
    
    var body: some View {
        GeometryReader{ geometry in
            ZStack{
                SpectrumView(node: node, shouldStroke: false, shouldAnalyzeTouch: false, shouldDisplayAxisLabels: false)
                Color.black.opacity(0.001) // just blocking the gesture of SpectrumView
                createFilterOverlay(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .onAppear {
                filterModel.updateNode(node)
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
                        node.cutoffFrequency = AUValue(expMap(n: x, start1: Float(0.0), stop1: Float(geometry.size.width), start2: Float(filterModel.minFreq), stop2: Float(filterModel.maxFreq)))
                        
                        node.resonance = AUValue(map(n: CGFloat(y), start1: 0.0, stop1: geometry.size.height, start2: 10.0, stop2: -10.0))
                    }
            )
        }
    }
    
    func createFilterOverlay(width: CGFloat, height: CGFloat) -> some View {
        
        var points : [CGPoint] = []
        
        let filterSlope = 200.0 // dB per decade
        let maxSpan: CGFloat = 170.0
        
        let x = logMap(n: filterModel.cutoff, start1: filterModel.minFreq, stop1: filterModel.maxFreq, start2: 0.0, stop2: Double(width))
        let y = map(n: Double(filterModel.resonance+25.0), start1: -10.0, stop1: 10.0, start2: Double(height), stop2: 0.0)
        
        let amplitudeKneeDrop = 12.0
        let kneeDropDecades = amplitudeKneeDrop / filterSlope
        let kneeDropFreq = filterModel.cutoff * pow(10, kneeDropDecades)
        let kneeDropX = logMap(n:  kneeDropFreq, start1: filterModel.minFreq, stop1: filterModel.maxFreq, start2: 0.0, stop2: Double(width))
        let kneeDropY = map(n: Double(-amplitudeKneeDrop), start1: -Double(maxSpan)/2.0, stop1: Double(maxSpan)/2.0, start2: Double(height), stop2: 0.0)
        
        let preKneeDecades = amplitudeKneeDrop / 20.0
        let preKneeFreq = filterModel.cutoff * pow(10, -preKneeDecades)
        let preKneeX = logMap(n:  preKneeFreq, start1: filterModel.minFreq, stop1: filterModel.maxFreq, start2: 0.0, stop2: Double(width))
        //let preKneeY = map(n: Double(0.0), start1: -10.0, stop1: 10.0, start2: Double(height), stop2: 0.0)
        
        let amplitudeDropToBottom = Double(maxSpan / 2.0)
        let numberOfDecades = amplitudeDropToBottom / filterSlope
        let newFreq = filterModel.cutoff * pow(10, numberOfDecades)
        let newX = logMap(n: newFreq, start1: filterModel.minFreq, stop1: filterModel.maxFreq, start2: 0.0, stop2: Double(width))
        
        points.append(CGPoint(x: 0.0, y: Double(height/2)))
        points.append(CGPoint(x: preKneeX, y: Double(height/2)))
        //points.append(CGPoint(x: x, y: y))
        
        
        //points.append(CGPoint(x: x, y: Double(height/2)))
        //points.append(CGPoint(x: x, y: y))
        points.append(CGPoint(x: kneeDropX, y: kneeDropY))
        points.append(CGPoint(x: newX, y: Double(height)))
        points.append(CGPoint(x: 0.0, y: Double(height)))
        points.append(CGPoint(x: 0.0, y: Double(height/2)))
        
        return ZStack{
            Path{ path in
                for (index, point) in points.enumerated() {
                    if index == 0 {
                        path.move(to: point)
                    } else if index == 2{
                        //path.addQuadCurve(to: points[index], control: CGPoint(x: x, y: Double(height/2)))
                        path.addCurve(to: points[index], control1: CGPoint(x: x, y: Double(height/2)), control2: CGPoint(x: x, y: y))
                    } else if index == 3 {
                        //path.addQuadCurve(to: points[index], control: CGPoint(x: x, y: Double(height/2)))
                        path.addCurve(to: points[index], control1: CGPoint(x: x, y: y), control2: CGPoint(x: x, y: Double(height/2)))
                    }
                    else {
                        path.addLine(to: point)
                    }
                }
            }
            .fill(fillColor)
            
            Path{ path in
                for (index, point) in points.enumerated() {
                    if index == 0 {
                        path.move(to: point)
                    } else if index == 2{
                        //path.addQuadCurve(to: points[index], control: CGPoint(x: x, y: Double(height/2)))
                        //path.addCurve(to: points[index], control1: CGPoint(x: x, y: Double(height/2)), control2: CGPoint(x: x, y: y))
                    } else if index == 3 {
                        //path.addQuadCurve(to: points[index], control: CGPoint(x: x, y: Double(height/2)))
                        path.addCurve(to: points[index], control1: CGPoint(x: x, y: Double(height/2)), control2: CGPoint(x: x, y: y))
                        //path.addCurve(to: points[index], control1: CGPoint(x: x, y: y), control2: CGPoint(x: x, y: Double(height/2)))
                    } else if index > points.count - 3 {}
                    else {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(strokeColor,style: StrokeStyle(lineWidth: 3,lineCap: .round, lineJoin: .bevel))
            
            /*Path{ path in
                for (index, point) in points.enumerated() {
                    if index == 0 {
                        path.move(to: point)
                    } else if index == 2 {
                        path.addQuadCurve(to: points[index+1], control: points[index])
                    }
                    else {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(strokeColor,lineWidth: 3)*/
        }
    }
    
}

struct FilterView_Previews: PreviewProvider {
    
    static var previews: some View {
        let lpf = LowPassFilter(Mixer())
        lpf.cutoffFrequency = 1270
        return FilterView(node: lpf).previewLayout(.fixed(width: 800, height: 500))
    }
}

struct FilterView2: View {
    let a0 = 1
    let a1 = -0.5
    let a2 = -0.25
    
    let b0 = 1
    let b1 = 3
    let b2 = 2
    
    let N = 1024 // number of points to evaluate at
    let upp = Double.pi
    
    
    var body: some View {
        var reals = [Double](repeating: 0.0, count: N)
        var imaginaries = [Double](repeating: -1.0, count: N)
        
        let spacing = upp / Double(N)
        for (index, real) in reals.enumerated() {
            reals[index] = Double(index) * spacing
        }
        
        var complexNumbers = DSPDoubleSplitComplex(realp: &reals, imagp: &imaginaries)
        
        
        
        
        return ZStack{
            
        }
    }
    
    /*public func exp<T:RealType>(z:Complex<T>) -> Complex<T> {
        let r = T.exp(z.re)
        let a = z.im
        return Complex(r * T.cos(a), r * T.sin(a))
    }*/
}
