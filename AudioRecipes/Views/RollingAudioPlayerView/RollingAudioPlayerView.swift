//
//  RollingAudioPlayerView.swift
//  AudioRecipes
//
//  Created by Macbook on 2/21/21.
//

import SwiftUI
import AudioKit
import AVFoundation

class RollingAudioPlayerModel: ObservableObject {
    @Environment(\.isPreview) var isPreview
    var node: AudioPlayer?

    //var audioInformation: (signal: [Float], rate: Double, frameCount: Int) = ([],0,0)
    let rmsFactor = 288.0
    var sampleRate = 0.0
    @Published var rmsVals: [Float] = []
    
    @Published var startIndex = 0
    @Published var endIndex = 200

    var trackLengthInSeconds: Double = 0.0
    var currentTime: TimeInterval = 0.0 {
        didSet {
            calculateNewIndexes()
            //rmsVals = getRMSValues(currentTime: currentTime, lengthOfTimeToDisplay: lengthOfTimeToDisplay)
        }
    }
    var lengthOfTimeToDisplay: TimeInterval = 1.0
    let fractionBeforePlayhead = 0.15
    var refreshTimer : RepeatingTimer
    
    init() {
        refreshTimer = RepeatingTimer(timeInterval: (1/60))
        refreshTimer.eventHandler = refreshUI
        if isPreview {
            for _ in 0...200 {
                rmsVals.append(Float.random(in: 0...0.8))
            }
        }
    }
    
    func updateNode(_ node: AudioPlayer) {
        if node !== self.node && !isPreview {
            self.node = node
            trackLengthInSeconds = node.duration
            getAllRMSValues()
            currentTime = node.getCurrentTime()
            refreshTimer.resume()
        }
    }
    
    func getAllRMSValues() {
        if let url = self.node?.file!.url {
            let audioInformation = loadAudioSignal(audioURL: url)
            let signal = audioInformation.signal
            sampleRate = audioInformation.rate
            rmsVals = createRMSAnalysisArray(signal: signal, windowSize: Int(sampleRate/rmsFactor))
        }
    }
    
    func calculateNewIndexes() {
        if let url = self.node?.file!.url {
            let timeBeforePlayhead = fractionBeforePlayhead * lengthOfTimeToDisplay
            let startOfShownTime = currentTime - timeBeforePlayhead
            startIndex = Int(startOfShownTime  * rmsFactor)
            endIndex = Int((startOfShownTime + lengthOfTimeToDisplay) * rmsFactor)
        }
    }
    
    func refreshUI() {
        DispatchQueue.main.async {
            self.currentTime = self.node?.getCurrentTime() ?? 0.0
        }
    }
}

struct RollingAudioPlayerView: View {
    @StateObject var rollingAudioPlayerModel = RollingAudioPlayerModel()
    var node: AudioPlayer
    @State var backgroundColor = Color.black
    @State var fillColor = Color.green
    
    var body: some View {
            GeometryReader { geometry in
                ZStack {

                    //VStack{
                        //Spacer(minLength: 0.0)
                        if rollingAudioPlayerModel.rmsVals.count > 0 {
                            createWave(width: geometry.size.width, height: geometry.size.height, rmsVals: rollingAudioPlayerModel.rmsVals)
                        }
                        //Spacer(minLength: 0.0)
                    //}
                    
                    createPlayheadLine(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .background(backgroundColor)
            .drawingGroup()
            .onAppear(){
                rollingAudioPlayerModel.updateNode(node)
            }
            .onDisappear(){
                rollingAudioPlayerModel.refreshTimer.cancel()
            }
    }
    
    func createPlayheadLine(width: CGFloat, height: CGFloat) -> some View  {
        let xLocation = width * CGFloat(rollingAudioPlayerModel.fractionBeforePlayhead)
        var points : [CGPoint] = []
        points.append(CGPoint(x: xLocation, y: 0.0))
        points.append(CGPoint(x: xLocation, y: height))
        
        return Path{ path in
            path.addLines(points)
        }
        .stroke(Color.white,lineWidth: 3)
    }
    
    func createWave(width: CGFloat, height: CGFloat, rmsVals: [Float]) -> some View {
        
        let numberOfPoints = rollingAudioPlayerModel.endIndex - rollingAudioPlayerModel.startIndex
        
        var points: [CGPoint] = []
        points.reserveCapacity(numberOfPoints*2+2)
        
        points.append(CGPoint(x: 0, y: height*0.5))
        
        for i in rollingAudioPlayerModel.startIndex..<rollingAudioPlayerModel.endIndex {
            let ii = i - rollingAudioPlayerModel.startIndex
            let x = ii.mapped(from: 0...numberOfPoints, to: 0...width)
            let y = CGFloat(rmsVals[i]).mappedInverted(from: 0...1, to: 0...height*0.5)
            points.append(CGPoint(x: x, y: y))
        }
        
        for i in stride(from: rollingAudioPlayerModel.endIndex, to: rollingAudioPlayerModel.startIndex, by: -1) {
            // let ii = endIndex - i
            let ii = i - rollingAudioPlayerModel.startIndex
            let x = ii.mapped(from: 0...numberOfPoints, to: 0...width)
            let y = CGFloat(rmsVals[i]).mapped(from: 0...1, to: height*0.5...height)
            points.append(CGPoint(x: x, y: y))
        }
        
        //points.append(CGPoint(x: width, y: height))
        
        let y = CGFloat(rmsVals[rollingAudioPlayerModel.startIndex]).mapped(from: 0...1, to: height*0.5...height)
        points.append(CGPoint(x: 0, y: y))
        points.append(CGPoint(x: 0, y: height*0.5))
        
        return ZStack{
            //Color.black

            /*Path{ path in
                path.move(to: points[0])
                points.forEach { point in
                    path.addLine(to: point)
                }
            }
            .fill(fillColor)*/
            
            /*ForEach(0..<points.count-1) { i in
                Path{ path in
                    path.move(to: points[i])
                    path.addLine(to: points[i+1])
                }
                .stroke(Color.white,lineWidth: 1)
            }*/
            
            Path{ path in
                path.addLines(points)
            }
            .fill(fillColor)
            
            Path{ path in
                path.addLines(points)
            }
            .stroke(Color.white,lineWidth: 1)

        }
    }
}

/*struct RunningAudioSegmentView: View {
    var floats : ContiguousArray<Float>
    @Binding var startIndex: Int
    @Binding var endIndex: Int
    var fractionBeforePlayhead: Double
    @State var fillColor : Color = Color.green
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack{
                    Spacer(minLength: 0.0)
                    if floats.count > 0 {
                        //createRectangles(width: geometry.size.width, height: geometry.size.height, rmsVals: floats)
                        createWave(width: geometry.size.width, height: geometry.size.height, rmsVals: floats)
                    }
                    Spacer(minLength: 0.0)
                }
                createPlayheadLine(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
    
    func createPlayheadLine(width: CGFloat, height: CGFloat) -> some View  {
        let xLocation = width * CGFloat(fractionBeforePlayhead)
        var points : [CGPoint] = []
        points.append(CGPoint(x: xLocation, y: 0.0))
        points.append(CGPoint(x: xLocation, y: height))
        
        return Path{ path in
            path.addLines(points)
        }
        .stroke(Color.white,lineWidth: 3)
    }

    /*func createRectangles(width: CGFloat, height: CGFloat, rmsVals: [Float]) -> some View {
        let playedIndex = Int(playPercentage * Double(rmsVals.count))
        //let maxValue = rmsVals.max() ?? 0.0
        let scalingFactor : Float = 1.0
        let numberOfRects = endIndex - startIndex
        let rectWidth = width / CGFloat(numberOfRects)
        
        return HStack(spacing: 0){
            ForEach(startIndex..<endIndex, id: \.self) { index in
                if index < playedIndex {
                    Rectangle()
                        .fill(playedColor).opacity(0.9)
                        .frame(width: rectWidth, height: CGFloat(rmsVals[index]*scalingFactor) * height)
                } else {
                    Rectangle()
                        .fill(unplayedColor).opacity(0.7)
                        .frame(width: rectWidth, height: CGFloat(rmsVals[index]*scalingFactor) * height)
                }
            }
        }
    }*/
    
    func createWave(width: CGFloat, height: CGFloat, rmsVals: ContiguousArray<Float>) -> some View {
        
        let numberOfPoints = endIndex - startIndex
        //let playedIndex = Int(playPercentage * Double(numberOfPoints))
        //let rectWidth = width / CGFloat(numberOfPoints)
        
        var points = ContiguousArray<CGPoint>()
        points.reserveCapacity(numberOfPoints*2+2)
        
        points.append(CGPoint(x: 0, y: height*0.5))
        
        for i in startIndex..<endIndex {
            let ii = i - startIndex
            let x = ii.mapped(from: 0...numberOfPoints, to: 0...width)
            let y = CGFloat(rmsVals[i]).mappedInverted(from: 0...1, to: 0...height*0.5)
            points.append(CGPoint(x: x, y: y))
        }
        
        for i in stride(from: endIndex, to: startIndex, by: -1) {
            // let ii = endIndex - i
            let ii = i - startIndex
            let x = ii.mapped(from: 0...numberOfPoints, to: 0...width)
            let y = CGFloat(rmsVals[i]).mapped(from: 0...1, to: height*0.5...height)
            points.append(CGPoint(x: x, y: y))
        }
        
        //points.append(CGPoint(x: width, y: height))
        points.append(CGPoint(x: 0, y: height*0.5))
        
        return ZStack{
            //Color.black

            Path{ path in
                //path.addLines(points)
                path.move(to: points[0])
                points.forEach { point in
                    path.addLine(to: point)
                }
            }
            //.stroke(Color.white,lineWidth: 1)
            .fill(fillColor)
            
            /*Path{ path in
                path.addLines(points)
            }
            .stroke(Color.white,lineWidth: 1)*/

        }
    }
    
}*/

struct RollingAudioPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        var file: AVAudioFile?
        let url = URL(fileURLWithPath: Bundle.main.resourcePath! + "/AnyKindOfWay.mp3")
        do{
            file = try AVAudioFile(forReading: url)
        } catch{
            print("oh no!")
        }
        let player = AudioPlayer(file: file!)!
        return RollingAudioPlayerView(node: player)
    }
}
