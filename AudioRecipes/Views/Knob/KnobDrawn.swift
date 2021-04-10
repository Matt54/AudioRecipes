import SwiftUI
import AVFoundation
import Combine

// MARK: KnobAUParameterControlModel
class KnobAUParameterControlModel: ObservableObject {
    var auParameter: AUParameter?
    var modulationManager: ModulationManager?
    var selectedModulation: Modulation? { didSet { updateModulationAssignment() } }
    
    /// 0.0 to 1.0 range
    @Published var displayValue : CGFloat = 0.5
    
    @Published var isAssigningModulation : Bool = false
    
    /// 0.0 to 1.0 range
    @Published var turnRatio : CGFloat = 0.0 {
        didSet{
            if isSetup {
                if let manager = modulationManager {
                    if let parameter = auParameter {
                        if manager.isParameterBeingModulated(parameter) {
                            manager.adjustAnchorValue(parameter, turnRatio: Float(turnRatio))
                        } else {
                            displayValue = turnRatio
                            parameter.value = manager.calculateParameterValueFromRangeValue(Float(turnRatio), min: parameter.minValue, max: parameter.maxValue, isLogRange: isLogRange)
                        }
                    }
                }
            }
        }
    }
    
    @Published var modulationMagnitude : CGFloat = 0.0
    @Published var modulationColor: Color = Color.yellow
    @Published var bounds : ClosedRange<CGFloat> = 0.0...1.0
    var isLogRange: Bool = false
    
    var isAssignedToSelectedModulation: Bool = false
    
    var isSetup: Bool = false
    
    var cancellableValueBinding: AnyCancellable?
    var cancellableAssignmentBinding: AnyCancellable?
    
    func updateAUParameter(auParameter: AUParameter, modulationManager: ModulationManager, isLogRange: Bool){
        if !modulationManager.isParameterBeingModulated(auParameter) {
            let rangeValue = CGFloat(modulationManager.calculateRangeValueFromParameterValue(auParameter.value, min: auParameter.minValue, max: auParameter.maxValue, isLogRange: isLogRange))
            turnRatio = rangeValue
            displayValue = rangeValue
        } else {
            turnRatio = CGFloat(modulationManager.getAnchorValueForParameter(auParameter))
        }
        
        self.auParameter = auParameter
        self.modulationManager = modulationManager
        if let modSelected = modulationManager.selectedModulation {
            selectedModulation = modSelected
        }
        self.isLogRange = isLogRange
        
        bindToCurrentRangeValue()
        bindToModulationAssignment()
        isSetup = true
    }
    
    func bindToCurrentRangeValue() {
        if let manager = modulationManager {
            if let parameter = auParameter {
                if let parameterInfo = manager.anchorValueDictionary[parameter.keyPath] {
                    cancellableValueBinding = parameterInfo.$currentRangeValue.receive(on: DispatchQueue.main)
                        .assign(to: \.displayValue, on: self)
                }
            }
        }
    }
    
    func bindToModulationAssignment() {
        if let manager = modulationManager {
            cancellableAssignmentBinding = manager.$isAssigningModulation.receive(on: DispatchQueue.main)
                .assign(to: \.isAssigningModulation, on: self)
        }
    }
    
    func updateModulationAssignment() {
        if let parameter = auParameter {
            if let target = selectedModulation?.getModulationTargetForParameter(auParameterKey: parameter.keyPath) {
                isAssignedToSelectedModulation = true
                modulationMagnitude = CGFloat(target.modulationMagnitude)
            } else {
                isAssignedToSelectedModulation = false
                modulationMagnitude = 0
            }
        }
    }
    
    func assignSelectedModulationToParameter() {
        if let manager = modulationManager {
            if let modulation = selectedModulation {
                if let parameter = auParameter {
                    manager.addParameterToModulation(modulation: modulation, auParameter: parameter, isLogRange: isLogRange)
                    updateModulationAssignment()
                    bindToCurrentRangeValue()
                }
            }
        }
    }

}

// MARK: KnobAUParameterControl
struct KnobAUParameterControl: View {
    @StateObject var knobAUParameterControlModel = KnobAUParameterControlModel()
    var auParameter: AUParameter?
    var modulationManager: ModulationManager?
    var isLogRange: Bool
    @State var isModulationAdjusting: Bool = false
    
    init(auParameter: AUParameter, modulationManager: ModulationManager, isLogRange: Bool = false) {
        self.auParameter = auParameter
        self.modulationManager = modulationManager
        self.isLogRange = isLogRange
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack{
                KnobModulationControl(value: $knobAUParameterControlModel.displayValue,
                                      turnRatio: $knobAUParameterControlModel.turnRatio,
                                      modulationMagnitude: $knobAUParameterControlModel.modulationMagnitude,
                                      bounds: knobAUParameterControlModel.bounds,
                                      modulationColor: knobAUParameterControlModel.modulationColor,
                                      isLogRange: isLogRange)
                    .onAppear{
                        if let manager = self.modulationManager {
                            if let parameter = self.auParameter {
                                knobAUParameterControlModel.updateAUParameter(auParameter: parameter,
                                                                              modulationManager: manager,
                                                                              isLogRange: self.isLogRange)
                            }
                        }
                    }
                if isModulationAdjusting {
                    KnobOverlayModulationAdjust(knobAUParameterControlModel: knobAUParameterControlModel,
                                                foregroundColor: knobAUParameterControlModel.modulationColor)
                }
                if knobAUParameterControlModel.isAssigningModulation && !knobAUParameterControlModel.isAssignedToSelectedModulation {
                    KnobOverlayModulationAssignment(knobAUParameterControlModel: knobAUParameterControlModel, foregroundColor: Color.green)
                }
            }
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.5)
                .onEnded{ value in
                    if(value == true){
                        isModulationAdjusting.toggle()
                    }
                }
            )
        }
    }
}

struct KnobAUParameterControl_Previews: PreviewProvider {
    static var previews: some View {
        KnobAUParameterControl(auParameter: AUParameter(), modulationManager: ModulationManager(sampleRate: 44_100))
    }
}

// MARK: KnobOverlayModulationAdjust
struct KnobOverlayModulationAssignment: View {
    var knobAUParameterControlModel : KnobAUParameterControlModel
    @State var foregroundColor: Color = Color.white
    @State var backgroundColor: Color = Color.black
    @State private var animationAmount: CGFloat = 1
    @State var location: CGPoint = CGPoint(x: 0, y: 0)
    var sensitivity: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            InteractionIndicatorView(imageSystemName: "goforward.plus",
                                     foregroundColor: foregroundColor,
                                     backgroundColor: backgroundColor)
                .onTapGesture {
                            knobAUParameterControlModel.assignSelectedModulationToParameter()
                }
        }
        
    }
}

struct KnobOverlayModulationAssignment_Previews: PreviewProvider {
    static var previews: some View {
        KnobOverlayModulationAssignment(knobAUParameterControlModel: KnobAUParameterControlModel())
    }
}

// MARK: KnobOverlayModulationAdjust
struct KnobOverlayModulationAdjust: View {
    var knobAUParameterControlModel : KnobAUParameterControlModel
    @State var foregroundColor: Color = Color.white
    @State var backgroundColor: Color = Color.black
    @State private var animationAmount: CGFloat = 1
    @State var location: CGPoint = CGPoint(x: 0, y: 0)
    var sensitivity: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            InteractionIndicatorView(imageSystemName: "cursorarrow.motionlines.click",
                                     foregroundColor: foregroundColor,
                                     backgroundColor: backgroundColor)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { gesture in
                    var delta = CGPoint(x: 0, y: 0)
                    
                    if (location.x != 0.0 && location.y != 0.0){
                        delta.x = location.x - gesture.location.x
                        delta.y = location.y - gesture.location.y
                    }
                    
                    location = gesture.location
                    
                    var valueChange = -delta.x / geometry.size.width * sensitivity
                    valueChange = valueChange + delta.y / geometry.size.width * sensitivity

                    if let mod = knobAUParameterControlModel.selectedModulation {
                        if let parameter = self.knobAUParameterControlModel.auParameter {
                            if let target = mod.getModulationTargetForParameter(auParameterKey: parameter.keyPath) {
                                target.modulationMagnitude = target.setModulationMagnitude(target.modulationMagnitude + Float(valueChange))
                                knobAUParameterControlModel.modulationMagnitude = CGFloat(target.modulationMagnitude)
                            }
                        }
                    }

                }
                .onEnded { _ in
                    location = CGPoint(x: 0, y: 0)
                }
            )
        }
        
    }
}

struct KnobOverlayModulationAdjust_Previews: PreviewProvider {
    static var previews: some View {
        KnobOverlayModulationAdjust(knobAUParameterControlModel: KnobAUParameterControlModel())
    }
}

// MARK: InteractionIndicatorView
struct InteractionIndicatorView: View {

    var imageSystemName: String
    @State var foregroundColor: Color = Color.white
    @State var backgroundColor: Color = Color.black
    @State private var animationAmount: CGFloat = 1
    
    var body: some View {
        GeometryReader { geometry in
            ZStack{
                Circle()
                    .opacity(0.01)
                Circle()
                    .fill(backgroundColor)
                    .opacity(0.8)
                    .frame(width: geometry.size.width < geometry.size.height ?
                                    geometry.size.width*0.375
                                    : geometry.size.height*0.375,
                           height: geometry.size.width < geometry.size.height ?
                                    geometry.size.width*0.375
                                    : geometry.size.height*0.375)
                .overlay(
                    Circle()
                        .stroke(foregroundColor, lineWidth: geometry.size.width < geometry.size.height ? geometry.size.width * 0.01 : geometry.size.height * 0.01 )
                        .scaleEffect(animationAmount)
                        .opacity(Double(2 - animationAmount))
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true)
                        )
                )
                .onAppear{
                    animationAmount = 2
                }
                Image(systemName: imageSystemName)
                    .resizable()
                    .imageStyle(UpsizeStyle())
                    .foregroundColor(foregroundColor)
                    .frame(width: geometry.size.width < geometry.size.height ?
                            geometry.size.width*0.3
                            : geometry.size.height*0.3,
                   height: geometry.size.width < geometry.size.height ?
                            geometry.size.width*0.3
                            : geometry.size.height*0.3)
                
            }
        }
        
    }
}

struct InteractionIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        InteractionIndicatorView(imageSystemName: "cursorarrow.motionlines.click")
    }
}

// MARK: KnobModulationControl
struct KnobModulationControl: View {
    @Binding var value: CGFloat
    @Binding var turnRatio: CGFloat
    @Binding var modulationMagnitude: CGFloat
    @State var bounds: ClosedRange<CGFloat> = 0...1
    @State var modulationColor: Color = Color.yellow
    var isLogRange: Bool = false
    
    var body: some View {
        
        let displayedModulationMagnitude = modulationMagnitude.clamped(to: -turnRatio...(1.0-turnRatio))
        
        return GeometryReader{ geometry in
            ZStack{
                //modulation background
                Arc(startAngle: .constant(130 * .pi / 180),
                    endAngle: .constant( (270.0 * 1.0 + 140.0) * .pi / 180.0),
                    lineWidth: geometry.size.width < geometry.size.height ?
                                geometry.size.width * 0.05
                                : geometry.size.height * 0.05,
                    center: CGPoint(x: geometry.size.width/2, y: geometry.size.height/2),
                    radius: geometry.size.width < geometry.size.height ?
                            geometry.size.width / 2 - geometry.size.width * 0.05 * 0.5
                            : geometry.size.height / 2 - geometry.size.height * 0.05 * 0.5)
                    .fill(Color.init(red: 0.5, green: 0.5, blue: 0.5))
                
                if(displayedModulationMagnitude > 0.0)
                {
                    Arc(startAngle: .constant((270.0 * turnRatio + 130) * .pi / 180),
                        endAngle: .constant((270 * displayedModulationMagnitude + 270.0 * turnRatio + 140.0) * .pi / 180.0),
                        lineWidth: geometry.size.width < geometry.size.height ?
                                    geometry.size.width * 0.05
                                    : geometry.size.height * 0.05,
                        center: CGPoint(x: geometry.size.width/2, y: geometry.size.height/2),
                        radius: geometry.size.width < geometry.size.height ?
                                geometry.size.width / 2 - geometry.size.width * 0.05 * 0.5
                                : geometry.size.height / 2 - geometry.size.height * 0.05 * 0.5)
                        .fill(modulationColor)
                }
                else{
                    Arc(startAngle: .constant((270 * displayedModulationMagnitude + 270.0 * turnRatio + 130.0) * .pi / 180.0),
                    endAngle: .constant((270.0 * turnRatio + 140) * .pi / 180),
                    lineWidth: geometry.size.width < geometry.size.height ?
                                geometry.size.width * 0.05
                                : geometry.size.height * 0.05,
                    center: CGPoint(x: geometry.size.width/2, y: geometry.size.height/2),
                    radius: geometry.size.width < geometry.size.height ?
                            geometry.size.width / 2 - geometry.size.width * 0.05 * 0.5
                            : geometry.size.height / 2 - geometry.size.height * 0.05 * 0.5)
                        .fill(modulationColor)
                }
                
                KnobValueTurnControl(value: $value,
                                     turnRatio: $turnRatio,
                                     bounds: bounds,
                                     isLogRange: isLogRange)
                    .frame(width: geometry.size.width < geometry.size.height ?
                                    geometry.size.width*0.9
                                    : geometry.size.height*0.9,
                           height: geometry.size.width < geometry.size.height ?
                                    geometry.size.width*0.9
                                    : geometry.size.height*0.9)
            }
        }
    }
}

struct KnobModulationControl_Previews: PreviewProvider {
    static var previews: some View {
        KnobModulationControl(value: .constant(0.5),
                              turnRatio: .constant(0.2),
                              modulationMagnitude: .constant(0.5))
            .frame(width: 400, height: 200)
    }
}

// MARK: KnobValueTurnControl
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
                    lineWidth: geometry.size.width < geometry.size.height ?
                                geometry.size.width * 0.05
                                : geometry.size.height * 0.05,
                    center: CGPoint(x: geometry.size.width/2, y: geometry.size.height/2),
                    radius: geometry.size.width < geometry.size.height ?
                            geometry.size.width / 2 - geometry.size.width * 0.05 * 0.5
                            : geometry.size.height / 2 - geometry.size.height * 0.05 * 0.5)
                    .fill(Color.yellow)
                KnobControlSimple(turnRatio: $turnRatio)
                    .frame(width: geometry.size.width < geometry.size.height ?
                                    geometry.size.width*0.9
                                    : geometry.size.height*0.9,
                           height: geometry.size.width < geometry.size.height ?
                                    geometry.size.width*0.9
                                    : geometry.size.height*0.9)
                
            }
        }
    }
}

struct KnobValueTurnControl_Previews: PreviewProvider {
    static var previews: some View {
        KnobValueTurnControl(value: .constant(0.5), turnRatio: .constant(0.5))
            .frame(width: 400, height: 200)
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

// MARK: KnobControlSimple
struct KnobControlSimple: View {
    // 0 to 1
    @Binding var turnRatio: CGFloat
    
    @State var location: CGPoint = CGPoint(x: 0, y: 0)
    var sensitivity: CGFloat = 1.0
    
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
                    
                    var valueChange = -delta.x / geo.size.width * sensitivity
                    valueChange = valueChange + delta.y / geo.size.width * sensitivity
                    
                    if turnRatio + valueChange > 1.0 {
                        turnRatio = 1.0
                    } else if turnRatio + valueChange < 0.0 {
                        turnRatio = 0.0
                    } else {
                        turnRatio = turnRatio + valueChange
                    }
                }
                .onEnded { _ in
                    location = CGPoint(x: 0, y: 0)
                }
            )
        }
    }
}

// MARK: KnobControl
struct KnobControl: View {
    @State var value: CGFloat
    @State var bounds: ClosedRange<CGFloat>
    var isLogRange: Bool
    
    // 0 to 1
    @State var turnRatio: CGFloat
    
    @State var location: CGPoint = CGPoint(x: 0, y: 0)
    var sensitivity: CGFloat = 1.0
    
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

// MARK: KnobView
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

// MARK: KnobDrawn
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
