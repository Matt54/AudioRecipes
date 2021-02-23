//
//  WavetableArrayExampleView.swift
//  AudioRecipes
//
//  Created by Matt Pfeiffer on 2/9/21.
//

import SwiftUI

struct WavetableArrayExampleView: View {
    @EnvironmentObject var conductor: Conductor
    
    var body: some View {
        VStack{
            ZStack{
                WavetableArrayView(conductor.osc,selectedValue: $conductor.wavePosition, realWavetableArray: conductor.waveforms)
            }
            Slider(value: $conductor.wavePosition, in: 0.0...255.0)
            Text("Wavetable Array Index Value: \(Int(conductor.wavePosition))")
                .foregroundColor(.white)
        }
        .background(Color.black)
        .navigationBarTitle(Text("Wavetable Array View"), displayMode: .inline)
    }
}

struct WavetableArrayExampleView_Previews: PreviewProvider {
    static var previews: some View {
        WavetableArrayExampleView().environmentObject(Conductor.shared)
    }
}
