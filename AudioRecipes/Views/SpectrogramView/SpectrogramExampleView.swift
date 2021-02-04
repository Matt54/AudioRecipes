import SwiftUI

struct SpectrogramExampleView: View{
    @EnvironmentObject var conductor: Conductor
    var body: some View{
        SpectrogramView(node: conductor.outputLimiter)
        .background(Color.black)
        .navigationBarTitle(Text("Spectrogram View"), displayMode: .inline)
    }
}

struct SpectrogramExampleView_Previews: PreviewProvider {
    static var previews: some View {
        SpectrogramExampleView().environmentObject(Conductor.shared)
    }
}
