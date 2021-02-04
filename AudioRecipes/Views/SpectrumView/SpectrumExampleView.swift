import SwiftUI

struct SpectrumExampleView: View{
    @EnvironmentObject var conductor: Conductor
    @State var variationType : VariationType = .defaultSpectrum
    @State var filterLowPassPercentage : Float = 1.0
    
    var body: some View{
        VStack(spacing: 0){
            Text("Variation: " + variationType.rawValue)
                .font(.largeTitle)
                .foregroundColor(.white)
            
            if variationType == .defaultSpectrum {
                SpectrumView(node: conductor.filter)
            } else {
                SpectrumView(node: conductor.filter)
                Slider(value: $filterLowPassPercentage, in: 0.0...1.0, step: 0.0001)
                    .accentColor(.green)
                    .onChange(of: filterLowPassPercentage, perform: { value in
                        conductor.filter.cutoffFrequency = Float(logSlider(position: value))

                    })
                Text("Low Pass Filter Cutoff = \(conductor.filter.cutoffFrequency, specifier: "%.0f") Hz.")
            }
            Button("Tap to vary view") {
                if variationType == .defaultSpectrum {
                    variationType = .lowPassFilter
                } else {
                    variationType = .defaultSpectrum
                }
            }
        }
        .background(Color.black)
        .navigationBarTitle(Text("Spectrum View"), displayMode: .inline)
    }
    
    enum VariationType : String {
        case defaultSpectrum = "Default"
        case lowPassFilter = "Low Pass Filter"
    }
    
    /*Text("Low Pass Filter Cutoff = \(conductor.filter.cutoffFrequency, specifier: "%.0f") Hz.")
        Slider(value: $filterLowPassPercentage, in: 0.0...1.0, step: 0.0001)
            .accentColor(.green)
            .onChange(of: filterLowPassPercentage, perform: { value in
                conductor.filter.cutoffFrequency = Float(logSlider(position: value))
                //print("ContentView.swift isRunning: " + String(conductor.engine.avEngine.isRunning))
                //print(conductor.filter.cutoffFrequency)
            })
        
    }*/
}

struct SpectrumExampleView_Previews: PreviewProvider {
    static var previews: some View {
        SpectrumExampleView()
    }
}

func logSlider(position: Float) -> Double {
    // position will be between 0 and 1.0
    let minp = 0.0;
    let maxp = 1.0;

    // The result should be between 30.0 an 20000.0
    let minv = log(30.0);
    let maxv = log(20000.0);

    // calculate adjustment factor
    let scale = (maxv-minv) / Double(maxp-minp);

    return exp(minv + scale*(Double(position)-minp));
}
