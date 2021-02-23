//
//  AudioPlayerView.swift
//  AudioRecipes
//
//  Created by Macbook on 2/13/21.
//

import SwiftUI
import AudioKit
import AVFoundation

class AudioFileMetadataModel: ObservableObject {
    @Published var hasImage = false
    var cpImage: CPImage?
    @Published var trackTitle: String = "No Title Found"
    @Published var trackArtist: String = "No Track Found"

    func updateFile(url: URL){
        analyzeMetadata(url: url)
    }
    
    func analyzeMetadata(url: URL) {
        let metadata = getPlayerItemInformation(url: url)
        cpImage = metadata.image
        trackTitle = metadata.title
        trackArtist = metadata.artist
        hasImage = true
    }
    
    func getPlayerItemInformation(url: URL) -> (image: CPImage, title: String, artist: String) {
        let playerItem = AVPlayerItem(url: url)
        let metadataList = playerItem.asset.metadata
        
        var image = CPImage()
        var title = ""
        var artist = ""
        
        for item in metadataList {

            guard let key = item.commonKey?.rawValue, let value = item.value else{
                continue
            }

           switch key {
           case "artwork" where value is Data : image = CPImage(data: value as! Data) ?? CPImage()
           case "title" : title = value as? String ?? ""
           case "artist": artist = value as? String ?? ""
            default:
              continue
           }
        }
        
        return (image: image, title: title, artist: artist)
    }
    
    func getFileName(url: URL, includeExtension: Bool = true) -> String {
        if includeExtension {
            return url.lastPathComponent
        } else {
            return url.lastPathComponent.components(separatedBy: ".").first ?? url.lastPathComponent
        }
    }
}

class AudioPlayerModel: ObservableObject {
    @Environment(\.isPreview) var isPreview
    var node: AudioPlayer?
    var rmsVals : [Float] = []
    var trackLengthInSeconds: Double = 0.0
    var currentTime: TimeInterval = 0.0 {
        didSet{
            playPercentage = currentTime / trackLengthInSeconds
        }
    }
    @Published var playPercentage: Double = 0.0
    
    @Published var isNodePlaying: Bool = false {
        didSet {
            setPlay()
        }
    }
    
    var refreshTimer : RepeatingTimer
    @Published var trackInfo = AudioFileMetadataModel()
    
    init() {
        refreshTimer = RepeatingTimer(timeInterval: 0.1)
        refreshTimer.eventHandler = refreshUI
        if isPreview {
            for _ in 0...200 {
                rmsVals.append(Float.random(in: 0...1.0))
            }
        }
    }
    
    func updateNode(_ node: AudioPlayer) {
        if node !== self.node && !isPreview {
            self.node = node
            rmsVals = getRMSValues()
            trackLengthInSeconds = node.duration
            currentTime = node.getCurrentTime()
            refreshTimer.resume()
            updateTrackInformation()
            isNodePlaying = node.isPlaying
        }
    }
    
    func updateTrackInformation() {
        if let url = self.node?.file!.url {
            trackInfo.updateFile(url: url)
        }
    }
    
    func getRMSValues() -> [Float] {
        if let url = self.node?.file!.url {
            let audioInformation = loadAudioSignal(audioURL: url)
            let signal = audioInformation.signal
            return createRMSAnalysisArray(signal: signal, windowSize: Int(audioInformation.rate/2))
        }
        return []
    }
    
    func refreshUI() {
        DispatchQueue.main.async {
            self.currentTime = self.node?.getCurrentTime() ?? 0.0
        }
    }
    
    func setPlay() {
        if let myNode = node {
            if isNodePlaying {
                myNode.play()
            } else {
                myNode.pause()
            }
        }
    }
}

class AudioPlayerSegmentModel: ObservableObject {
    @Environment(\.isPreview) var isPreview
    var node: AudioPlayer?

    //var audioInformation: (signal: [Float], rate: Double, frameCount: Int) = ([],0,0)
    let rmsFactor = 288.0
    var sampleRate = 0.0
    @Published var allRMSValues = ContiguousArray<Float>()
    @Published var rmsVals : [Float] = []
    
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
                rmsVals.append(Float.random(in: 0...1.0))
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
            allRMSValues = createRMSAnalysisArray(signal: signal, windowSize: Int(sampleRate/rmsFactor))
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
    
    func getRMSValues(currentTime: TimeInterval, lengthOfTimeToDisplay: TimeInterval) -> [Float] {
        if let url = self.node?.file!.url {
            
            let timeBeforePlayhead = fractionBeforePlayhead * lengthOfTimeToDisplay
            
            let startOfShownTime = currentTime - timeBeforePlayhead
            
            //let audioInformation = loadAudioSignal(audioURL: url)
            //let audioInformation = loadAudioSignal(audioURL: url)
            //let signal = audioInformation.signal
            //let startSample = Int(currentTime * audioInformation.rate)
            //var endSample = Int((currentTime + lengthOfTimeToDisplay) * audioInformation.rate)
            let startRMSIndex = Int(startOfShownTime  * rmsFactor)
            var endRMSIndex = Int((startOfShownTime + lengthOfTimeToDisplay) * rmsFactor)
            
            var zeroPaddedSamples : Int = 0
            /*if endSample > audioInformation.frameCount {
                zeroPaddedSamples = endSample - audioInformation.frameCount
                endSample = audioInformation.frameCount
            }*/
            
            return Array(allRMSValues[startRMSIndex..<endRMSIndex])
            
            
            //return createRMSAnalysisArray(signal: signalSlice, windowSize: Int(audioInformation.rate/288))
            //return []
        }
        return []
    }
    
    func refreshUI() {
        DispatchQueue.main.async {
            self.currentTime = self.node?.getCurrentTime() ?? 0.0
        }
    }
}

struct AudioTrackView: View {
    @StateObject var audioPlayerModel = AudioPlayerModel()
    //@StateObject var audioPlayerSegmentModel = AudioPlayerSegmentModel()
    
    var node: AudioPlayer
    @State var backgroundColor = Color.black
    @State var unplayedColor = Color.white
    @State var playedColor = Color.green
    //@State var buttonForegroundColor = Color.white
   // @State var buttonBackgroundColor = Color.green
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                
                SquareImageView(cpImage: audioPlayerModel.trackInfo.cpImage)
                    .frame(height: geometry.size.height * 0.5)
                
                
                
                /*RunningAudioSegmentView(floats: audioPlayerSegmentModel.allRMSValues,
                                        startIndex: $audioPlayerSegmentModel.startIndex,
                                        endIndex: $audioPlayerSegmentModel.endIndex,
                                        fractionBeforePlayhead: audioPlayerSegmentModel.fractionBeforePlayhead,
                                     playPercentage: .constant(1.0),
                                     unplayedColor: unplayedColor,
                                     playedColor: playedColor)
                    .drawingGroup()*/
                
                PlayableFileDataView(floats: audioPlayerModel.rmsVals,
                                     playPercentage: $audioPlayerModel.playPercentage,
                                     unplayedColor: unplayedColor,
                                     playedColor: playedColor)
                    .drawingGroup()
                    //.drawingGroup()
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { value in
                                var x: CGFloat = value.location.x > geometry.size.width ? geometry.size.width : 0.0
                                if value.location.x > 0.0 && value.location.x < geometry.size.width {
                                    x = value.location.x
                                }
                                let seekLocation = Float(audioPlayerModel.trackLengthInSeconds) * Float(x/geometry.size.width)
                                audioPlayerModel.node?.seek(time: seekLocation)
                            }
                    )
                    
                    //.id(audioPlayerSegmentModel.rmsVals)
                
                
                
                PlaybackBannerView(trackArtist: $audioPlayerModel.trackInfo.trackArtist,
                                   trackTitle: $audioPlayerModel.trackInfo.trackTitle,
                                   currentTime: $audioPlayerModel.currentTime,
                                   totalTime: $audioPlayerModel.trackLengthInSeconds,
                                   isPlaying: $audioPlayerModel.isNodePlaying)
                    .frame(maxHeight: 100)
                    //.frame(minHeight: 50, idealHeight: geometry.size.height * 0.1, maxHeight: 100)
                    .background(Color.white).opacity(0.8)
                    .drawingGroup()
            }
            
            .background(backgroundColor)
            .onAppear(){
                audioPlayerModel.updateNode(node)
                //audioPlayerSegmentModel.updateNode(node)
            }
            .onDisappear(){
                audioPlayerModel.refreshTimer.cancel()
                //audioPlayerSegmentModel.refreshTimer.cancel()
            }
            
            
        }//.drawingGroup()
    }
}

struct MarqueeText : View {
    var text : String
    @State private var animate = false
    private let animationOne = Animation.linear(duration: 8).repeatForever(autoreverses: false)

    var body : some View {
        let pointSize = CPFont.preferredFont(forTextStyle: .title1).pointSize
        let stringWidth = text.widthOfString(usingFont: CPFont.systemFont(ofSize: pointSize))
        return ZStack {
                GeometryReader { geometry in
                    Text(text).lineLimit(1)
                        .font(.title)
                        .offset(x: animate ? -stringWidth * 2 : 0)
                        .animation(animationOne)
                        .onAppear() {
                            animate = true
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .leading)
                    
                    Text(text).lineLimit(1)
                        .font(.title)
                        .offset(x: animate ? 0 : stringWidth * 2)
                        .animation(animationOne)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .leading)

                }
        }
    }
}

struct PlaybackBannerView: View {
    @Binding var trackArtist : String
    @Binding var trackTitle : String
    
    @Binding var currentTime : Double
    @Binding var totalTime : Double
    @Binding var isPlaying : Bool
    
    var buttonForegroundColor = Color.white
    var buttonBackgroundColor = Color.green

    var body: some View {
        
        let currentTimeText = getFileTimeText(time: currentTime)
        let totalTimeText = getFileTimeText(time: totalTime)
        
        return GeometryReader{ geometry in
            HStack(spacing : 0){
                Button(action: togglePlay, label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .resizable()
                        .padding()
                        .aspectRatio(1.0, contentMode: .fit)
                        .foregroundColor(buttonForegroundColor)
                        .background(buttonBackgroundColor)
                })
                
                VStack(spacing: 0){
                    MarqueeText(text: trackTitle + " - " + trackArtist)
                        .id(trackTitle + " - " + trackArtist)
                        .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))

                    HStack{
                        Text(currentTimeText)
                            .font(.headline)
                            .foregroundColor(Color.black).opacity(0.9)
                            .padding(.leading)
                        Spacer()
                        Text(totalTimeText)
                            .font(.headline)
                            .foregroundColor(Color.black).opacity(0.9)
                            .padding(.trailing)
                    }
                    .padding(.bottom)
                }
            }
        }
    }
    
    func getFileTimeText(time: Double) -> String{
        let totalMinutes = Int(time / 60.0)
        let totalSeconds = Int(time) % 60
        let totalZeroPadding = totalSeconds > 9 ? "" : "0"
        return "\(totalMinutes):\(totalZeroPadding)\(totalSeconds)"
    }
    
    func togglePlay() {
        isPlaying.toggle()
    }
    
}

struct SquareImageView: View {
    var cpImage: CPImage?
    
    var body: some View {
        GeometryReader{ geo in
            VStack{
                Spacer(minLength: 0)
                    HStack {
                        Spacer(minLength: 0)
                        ZStack{
                            if cpImage != nil {
                                Image(cpImage: cpImage!)
                                    .resizable()
                            } else {
                                Color.gray
                                Text("No Image Provided")
                            }
                        }
                        .frame(width: geo.size.width > geo.size.height ? geo.size.height : geo.size.width,
                               height: geo.size.width > geo.size.height ? geo.size.height : geo.size.width)
                        Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct PlayableFileDataView: View {
    var floats : [Float]
    @Binding var playPercentage: Double
    @State var unplayedColor : Color = Color.gray
    @State var playedColor : Color = Color.green
    
    var body: some View {
        GeometryReader { geometry in
            createRectangles(width: geometry.size.width, height: geometry.size.height, rmsVals: floats)
        }
    }

    func createRectangles(width: CGFloat, height: CGFloat, rmsVals: [Float]) -> some View {
        let playedIndex = Int(playPercentage * Double(rmsVals.count))
        let maxValue = rmsVals.max() ?? 0.0
        let scalingFactor = 1.0 / maxValue
        let rectWidth = width / CGFloat(rmsVals.count)
        return HStack(spacing: 0){
            ForEach(rmsVals.indices, id: \.self) { index in
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
    }
}

struct RunningAudioSegmentView: View {
    var floats : ContiguousArray<Float>
    @Binding var startIndex: Int
    @Binding var endIndex: Int
    var fractionBeforePlayhead: Double
    @Binding var playPercentage: Double
    @State var unplayedColor : Color = Color.gray
    @State var playedColor : Color = Color.green
    
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

    func createRectangles(width: CGFloat, height: CGFloat, rmsVals: [Float]) -> some View {
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
    }
    
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
            .fill(Color.green)
            
            /*Path{ path in
                path.addLines(points)
            }
            .stroke(Color.white,lineWidth: 1)*/

        }
    }
    
}

struct AudioTrackView_Previews: PreviewProvider {
    static var previews: some View {
        var file: AVAudioFile?
        let url = URL(fileURLWithPath: Bundle.main.resourcePath! + "/AnyKindOfWay.mp3")
        do{
            file = try AVAudioFile(forReading: url)
        } catch{
            print("oh no!")
        }
        let player = AudioPlayer(file: file!)!
        return AudioTrackView(node: player)
    }
}
