import SwiftUI

struct AmplitudeExampleView: View {
    @EnvironmentObject var conductor: Conductor
    @State var variationType : VariationType = .defaultAmplitudeView
    
    var body: some View {
        ZStack{
            VStack(spacing: 0){
                
                Text("Variation: " + variationType.rawValue)
                    .font(.largeTitle)
                    .foregroundColor(.white)
                
                if variationType == .stereoExample{
                    HStack{
                        VStack{
                            AmplitudeView(conductor.panner, stereoMode: .left)
                            Text("Left")
                                .foregroundColor(.white)
                        }
                        VStack{
                            AmplitudeView(conductor.secondCombinationMixer, stereoMode: .right)
                            Text("Right")
                                .foregroundColor(.white)
                        }
                    }
                    Slider(value: $conductor.pan, in: -1.0...1.0)
                    Text("Panning: \(conductor.pan, specifier: "%.2f")")
                        .foregroundColor(.white)
                } else if variationType == .defaultAmplitudeView {
                    AmplitudeView(conductor.panner)
                } else {
                    AmplitudeView(conductor.panner, numberOfSegments: 1)
                }
            }
            TapView()
        }
        .background(Color.black)
        .navigationBarTitle(Text("Amplitude View"), displayMode: .inline)
        .onTapGesture{
            if variationType == .stereoExample {
                variationType = .defaultAmplitudeView
            } else if variationType == .defaultAmplitudeView {
                variationType = .oneSegmentExample
            } else {
                variationType = .stereoExample
            }
        }
    }
    
    enum VariationType : String {
        case defaultAmplitudeView = "Default"
        case oneSegmentExample = "One Segment"
        case stereoExample = "Stereo Mode"
    }
    
}

struct AmplitudeExampleView_Previews: PreviewProvider {
    static var previews: some View {
        AmplitudeExampleView().environmentObject(Conductor.shared)
    }
}
