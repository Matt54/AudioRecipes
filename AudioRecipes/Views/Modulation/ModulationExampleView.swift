//
//  ModulationExampleView.swift
//  AudioRecipes
//
//  Created by Matt Pfeiffer on 3/11/21.
//

import SwiftUI

struct ModulationExampleView: View {
    @EnvironmentObject var conductor: Conductor
    
    var body: some View {
        VStack{
            GeometryReader{ geo in
                HStack{
                    Spacer()
                    SpectrogramView(node: conductor.outputLimiter)
                        .frame(width: geo.size.width * 0.5)
                    Spacer()
                }
            }
            
            if conductor.modulations.count > 0 {
                ForEach((0..<conductor.modulations.count), id: \.self) { i in
                    ModFrequencyView(modulation: $conductor.modulations[i])
                }
                
            } else {
                Text("No Modulations Found")
            }
        }
        .background(Color.black)
        .navigationBarTitle(Text("Spectrogram View"), displayMode: .inline)
    }
}

struct ModulationExampleView_Previews: PreviewProvider {
    static var previews: some View {
        ModulationExampleView().environmentObject(Conductor.shared)
    }
}
