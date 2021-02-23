//
//  AudioFileExampleView.swift
//  AudioRecipes
//
//  Created by Matt Pfeiffer on 2/11/21.
//

import SwiftUI

/*struct AudioFileExampleView: View {
    @EnvironmentObject var conductor: Conductor
    
    var body: some View {
        let wavetableURL = URL(fileURLWithPath: Bundle.main.resourcePath! + "/AnyKindOfWay.mp3")
        let audioInformation = loadAudioSignal(audioURL: wavetableURL)
        let signal = audioInformation.signal
        let rmsVals = createRMSAnalysisArray(signal: signal, windowSize: Int(audioInformation.rate/2))

        return AudioFileView(floats: rmsVals, playPercentage: .constant(0.2))
        .background(Color.black)
        .navigationBarTitle(Text("Audio File View"), displayMode: .inline)
    }
}

struct AudioFileExampleView_Previews: PreviewProvider {
    static var previews: some View {
        AudioFileExampleView().environmentObject(Conductor.shared)
    }
}
*/
