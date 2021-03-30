//
//  ModFrequencyView.swift
//  AudioRecipes
//
//  Created by Matt Pfeiffer on 3/11/21.
//

import SwiftUI

struct ModFrequencyView: View {
    @Binding var modulation: Modulation
    @State var frequencyPercentage : Float = 0.5
    
    var body: some View {
        Toggle(isOn: $modulation.isOn){
            Text("\(modulation.name) Frequency = \(modulation.frequency, specifier: "%.2f") Hz.")
                .foregroundColor(.white)
        }

        Slider(value: $frequencyPercentage, in: 0.01...10.0, step: 0.0001)
            .accentColor(.green)
            .onChange(of: frequencyPercentage, perform: { value in
                modulation.frequency = frequencyPercentage
            })
            .onAppear{
                frequencyPercentage = modulation.frequency
            }
    }
}

struct ModFrequencyView_Previews: PreviewProvider {
    static var previews: some View {
        ModFrequencyView(modulation: .constant(Modulation(frequency: 1)))
    }
}
