import SwiftUI

struct FFTExampleView: View{
    @EnvironmentObject var conductor: Conductor
    @State var currentGradient = 0
    @State var includeCaps = true
    @State var numberOfBars = 50
    @State var variationType : VariationType = .defaultFFT
    @State var colorGradients : [Gradient] = [Gradient(colors: [.red, .yellow, .green]),
                                              Gradient(colors: [Color.init(hex: "D16BA5"), Color.init(hex: "86A8E7"), Color.init(hex: "5FFBF1")]),
                                              Gradient(colors: [Color.init(hex: "d902ee"), Color.init(hex: "F4AF1B"), Color.init(hex: "F2BC94")])]
    
    var body: some View{
        ZStack{
            VStack(spacing: 0){
                Text("Variation: " + variationType.rawValue)
                    .font(.largeTitle)
                    .foregroundColor(.white)
                
                if variationType == .defaultFFT{
                    FFTView(conductor.filter)
                } else if variationType == .noPadding {
                    FFTView(conductor.filter, linearGradient: LinearGradient(gradient: colorGradients[1], startPoint: .top, endPoint: .center), paddingFraction: 0.0)
                } else if variationType == .moreBars {
                    FFTView(conductor.filter, numberOfBars: 100)
                } else {
                    FFTView(conductor.filter, linearGradient: LinearGradient(gradient: colorGradients[2], startPoint: .top, endPoint: .center), includeCaps: false)
                }
            }
            TapView()
        }
        .background(Color.black)
        .navigationBarTitle(Text("FFT View"), displayMode: .inline)
        .onTapGesture {
            if variationType == .defaultFFT {
                variationType = .noPadding
            } else if variationType == .noPadding {
                variationType = .moreBars
            } else if variationType == .moreBars {
                variationType = .noCaps
            } else {
                variationType = .defaultFFT
            }
        }
            
    }
    
    enum VariationType : String {
        case defaultFFT = "Default"
        case noPadding = "No Padding"
        case moreBars = "More Bars"
        case noCaps = "No Caps"
    }
    
}

struct FFTExampleView_Previews: PreviewProvider {
    static var previews: some View {
        FFTExampleView().environmentObject(Conductor.shared)
    }
}
