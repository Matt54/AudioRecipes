//
//  AudioPlayerExampleView.swift
//  AudioRecipes
//
//  Created by Macbook on 2/13/21.
//

import SwiftUI

struct AudioPlayerExampleView: View {
    @EnvironmentObject var conductor: Conductor
    
    var body: some View {
        return AudioTrackView(node: conductor.player)
        .background(Color.black)
        .navigationBarTitle(Text("Audio Track View"), displayMode: .inline)
    }
}

struct AudioPlayerExampleView_Previews: PreviewProvider {
    static var previews: some View {
        AudioPlayerExampleView().environmentObject(Conductor.shared)
    }
}
