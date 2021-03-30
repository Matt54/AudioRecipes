import SwiftUI

struct KnobExampleView: View{
    @EnvironmentObject var conductor: Conductor
    var body: some View{
        VStack{
            KnobControl(value: 0.5)
        }
        .background(Color.black)
        .navigationBarTitle(Text("Knob Example View"), displayMode: .inline)
    }
}

struct KnobViewExample_Previews: PreviewProvider {
    static var previews: some View {
        KnobExampleView().environmentObject(Conductor.shared)
    }
}
