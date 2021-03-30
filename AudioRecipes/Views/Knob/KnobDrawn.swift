import SwiftUI
import AVFoundation

struct KnobAUParameterControl: View {
    
    var auParameter: AUParameter
    
    @State var value: CGFloat
    @State var turnRatio: CGFloat
    @State var modulationMagnitude: CGFloat
    @State var bounds: ClosedRange<CGFloat>
    var isLogRange: Bool
    
    init(auParameter: AUParameter, isLogRange: Bool = false) {
        self.auParameter = auParameter
        self._value = State(initialValue: CGFloat(auParameter.value))
        self._bounds = State(initialValue: CGFloat(auParameter.minValue)...CGFloat(auParameter.maxValue))
        self._turnRatio = State(initialValue: CGFloat(auParameter.value))
        self._modulationMagnitude = State(initialValue: 0)
        self.isLogRange = isLogRange
    }
    
    var body: some View {
        KnobModulationControl(value: $value,
                              turnRatio: $turnRatio,
                              modulationMagnitude: $modulationMagnitude,
                              bounds: bounds,
                              isLogRange: isLogRange)
    }
}

struct KnobModulationControl: View {
    @Binding var value: CGFloat
    @Binding var turnRatio: CGFloat
    @Binding var modulationMagnitude: CGFloat
    @State var bounds: ClosedRange<CGFloat> = 0...1
    var isLogRange: Bool = false
    
    var body: some View {
        
        // This prevents the modulation arc from passing its bounds
        var magnitudeDisplayed = modulationMagnitude
        if (modulationMagnitude + turnRatio > 1.0) {
            magnitudeDisplayed = 1.0 - turnRatio
        } else if (modulationMagnitude + turnRatio < 0.0) {
            magnitudeDisplayed = turnRatio * -1
        }
        
        return GeometryReader{ geometry in
            ZStack{
                //modulation background
                Arc(startAngle: .constant(130 * .pi / 180),
                    endAngle: .constant( (270.0 * 1.0 + 140.0) * .pi / 180.0),
                    lineWidth: geometry.size.width * 0.05,
                    center: CGPoint(x: geometry.size.width/2, y: geometry.size.height/2),
                    radius: geometry.size.width/2 - geometry.size.width * 0.05 * 0.5)
                    .fill(Color.init(red: 0.5, green: 0.5, blue: 0.5))
                
                if(modulationMagnitude > 0.0)
                {
                    Arc(startAngle: .constant((270.0 * turnRatio + 130) * .pi / 180),
                        endAngle: .constant((270 * magnitudeDisplayed + 270.0 * turnRatio + 140.0) * .pi / 180.0),
                        lineWidth: geometry.size.width * 0.05,
                        center: CGPoint(x: geometry.size.width/2, y: geometry.size.height/2),
                        radius: geometry.size.width/2 - geometry.size.width * 0.05 * 0.5)
                        .fill(Color.yellow)
                }
                else{
                    Arc(startAngle: .constant((270 * magnitudeDisplayed + 270.0 * turnRatio + 130.0) * .pi / 180.0),
                    endAngle: .constant((270.0 * turnRatio + 140) * .pi / 180),
                    lineWidth: geometry.size.width * 0.05,
                    center: CGPoint(x: geometry.size.width/2, y: geometry.size.height/2),
                    radius: geometry.size.width/2 - geometry.size.width * 0.05 * 0.5)
                        .fill(Color.yellow)
                }
                
                KnobValueTurnControl(value: $value,
                                     turnRatio: $turnRatio,
                                     bounds: bounds,
                                     isLogRange: isLogRange)
                    .frame(width: geometry.size.width * 0.9)
            }
        }
    }
}

struct KnobModulationControl_Previews: PreviewProvider {
    static var previews: some View {
        KnobModulationControl(value: .constant(0.5),
                              turnRatio: .constant(0.2),
                              modulationMagnitude: .constant(0.5))
    }
}

struct KnobValueTurnControl: View {
    @Binding var value: CGFloat
    @Binding var turnRatio: CGFloat
    @State var bounds: ClosedRange<CGFloat> = 0...1
    var isLogRange: Bool = false
    
    var body: some View {
        GeometryReader{ geometry in
            ZStack{
                Circle()
                Arc(startAngle: .constant((270.0 * value + 130) * .pi / 180),
                    endAngle: .constant( (270.0 * value + 140.0) * .pi / 180.0),
                    lineWidth: geometry.size.width * 0.05,
                    center: CGPoint(x: geometry.size.width/2, y: geometry.size.height/2),
                    radius: geometry.size.width / 2 - geometry.size.width * 0.05 * 0.5)
                    .fill(Color.yellow)
                KnobControl(value: turnRatio, bounds: bounds, isLogRange: isLogRange)
                    .frame(width: geometry.size.width * 0.9)
            }
        }
    }
}

struct KnobValueTurnControl_Previews: PreviewProvider {
    static var previews: some View {
        KnobValueTurnControl(value: .constant(0.5), turnRatio: .constant(0.5))
    }
}

struct Arc : Shape {
@Binding var startAngle: CGFloat
@Binding var endAngle: CGFloat

var lineWidth: CGFloat
var center: CGPoint
var radius: CGFloat
    func path(in rect: CGRect) -> Path
    {
        var path = Path()

        let cgPath = CGMutablePath()
        
        cgPath.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                      radius: radius,
                      startAngle: startAngle,
                      endAngle: endAngle,
                      clockwise: false)

        path = Path(cgPath)

        return path.strokedPath(.init(lineWidth: lineWidth, lineCap: .butt))
    }
}

struct KnobControl: View {
    @State var value: CGFloat
    @State var bounds: ClosedRange<CGFloat>
    var isLogRange: Bool
    
    // 0 to 1
    @State var turnRatio: CGFloat
    
    @State var location: CGPoint = CGPoint(x: 0, y: 0)
    var sensitivity: CGFloat = 1.0;
    
    init(value: CGFloat, bounds: ClosedRange<CGFloat> = 0...1, isLogRange: Bool = false) {
        self.isLogRange = isLogRange
        self._value = State(initialValue: value)
        self._bounds = State(initialValue: bounds)
        self._turnRatio = State(initialValue: value.mapped(from: bounds))
    }
    
    var body: some View {
        GeometryReader{ geo in
            KnobView(percentRotated: $turnRatio)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { gesture in
                    var delta = CGPoint(x: 0, y: 0)
                    
                    if (location.x != 0.0 && location.y != 0.0){
                        delta.x = location.x - gesture.location.x
                        delta.y = location.y - gesture.location.y
                    }
                    
                    location = gesture.location
                    
                    var valueChange = delta.x / geo.size.width * sensitivity
                    valueChange = valueChange - delta.y / geo.size.width * sensitivity
                    
                    if turnRatio + valueChange > 1.0 {
                        turnRatio = 1.0
                    } else if turnRatio + valueChange < 0.0 {
                        turnRatio = 0.0
                    } else {
                        turnRatio = turnRatio + valueChange
                    }
                    updateControlValue()
                }
                .onEnded { _ in
                    location = CGPoint(x: 0, y: 0)
                }
            )
        }
    }
    
    func updateControlValue() {
        if isLogRange {
            value = turnRatio.mappedExp(to: bounds)
        } else {
            value = turnRatio.mapped(to: bounds)
        }
    }
    
}

struct KnobControl_Previews: PreviewProvider {
    static var previews: some View {
        KnobControl(value: 0.5)
    }
}

/// This is the "dumb" knob display - does not respond to gesture
struct KnobView: View {
    @Binding var percentRotated: CGFloat
    @State var strokeColor: Color = Color.black
    @State var fillColor: Color = Color.gray
    
    var body: some View {
        KnobDrawn(strokeColor: strokeColor, fillColor: fillColor)
            .rotationEffect(.degrees(-135 + Double(percentRotated) * 270))
    }
}

struct KnobView_Previews: PreviewProvider {
    static var previews: some View {
        KnobView(percentRotated: .constant(0.5))
    }
}

struct KnobDrawn: View {
    @State var strokeColor: Color
    @State var fillColor: Color
    
    var body: some View {
        GeometryReader{ geo in
            ZStack{
                Circle()
                    .fill(fillColor)
                createStroke(width: geo.size.width, height: geo.size.height)
            }
        }
    }
    
    // this always keeps the stroke inside the circle
    func createStroke(width: CGFloat, height: CGFloat) -> some View {
        let lineWidth: CGFloat = 10.0
        var points : [CGPoint] = []
        points.append(CGPoint(x: width/2, y: height/2))
        if width > height {
            points.append(CGPoint(x: width/2, y: height/2-height/2))
        } else {
            points.append(CGPoint(x: width/2, y: height/2-width/2))
        }
        return Path{ path in
                path.addLines(points)
                }
        .stroke(strokeColor,style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }
    
}

struct KnobDrawn_Previews: PreviewProvider {
    static var previews: some View {
        KnobDrawn(strokeColor: Color.white, fillColor: Color.black)
    }
}
