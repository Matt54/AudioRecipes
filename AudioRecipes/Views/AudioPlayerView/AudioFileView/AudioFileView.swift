//
//  AudioFileView.swift
//  AudioRecipes
//
//  Created by Matt Pfeiffer on 2/11/21.
//

import SwiftUI

/*struct AudioFileView: View {
    var floats : [Float]
    @State var backgroundColor : Color = Color.black
    @State var unplayedColor : Color = Color.gray
    @State var playedColor : Color = Color.green
    @Binding var playPercentage: Float
    
    var body: some View {
        return GeometryReader { geometry in
            ZStack {
                backgroundColor
                createRectangles(width: geometry.size.width, height: geometry.size.height, rmsVals: floats)
            }
        }
    }

    func createRectangles(width: CGFloat, height: CGFloat, rmsVals: [Float]) -> some View {
        let playedIndex = Int(playPercentage * Float(rmsVals.count))
        let maxValue = rmsVals.max()!
        let scalingFactor = 1.0 / maxValue
        let rectWidth = width / CGFloat(rmsVals.count)
        return HStack(spacing: 0){
            ForEach(rmsVals.indices, id: \.self) { index in
                if index < playedIndex {
                    Rectangle()
                        .fill(playedColor)
                        .frame(width: rectWidth, height: CGFloat(rmsVals[index]*scalingFactor) * height)
                } else {
                    Rectangle()
                        .fill(unplayedColor)
                        .frame(width: rectWidth, height: CGFloat(rmsVals[index]*scalingFactor) * height)
                }
            }
        }
    }
}*/

/*struct AudioFileView_Previews: PreviewProvider {
    static var previews: some View {
        let wavetableURL = URL(fileURLWithPath: Bundle.main.resourcePath! + "/AnyKindOfWay.mp3")
        let audioInformation = loadAudioSignal(audioURL: wavetableURL)
        let signal = audioInformation.signal
        let rmsVals = createRMSAnalysisArray(signal: signal, windowSize: Int(audioInformation.rate/2))
        AudioFileView(floats: rmsVals,playPercentage: .constant(0.2))
    }
}*/
