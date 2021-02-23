//
//  RollingAudioPlayerExampleView.swift
//  AudioRecipes
//
//  Created by Macbook on 2/21/21.
//

import SwiftUI

struct RollingAudioPlayerExampleView: View {
    @EnvironmentObject var conductor: Conductor
    
    var body: some View {
        return RollingAudioPlayerView(node: conductor.player)
        .background(Color.black)
        .navigationBarTitle(Text("Rolling Audio Player View"), displayMode: .inline)
    }
}

struct RollingAudioPlayerExampleView_Previews: PreviewProvider {
    static var previews: some View {
        RollingAudioPlayerExampleView().environmentObject(Conductor.shared)
    }
}
