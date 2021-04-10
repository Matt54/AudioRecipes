import SwiftUI

struct KnobExampleView: View{
    @EnvironmentObject var conductor: Conductor
    var body: some View{
        VStack{
            if conductor.parameters.count > 0 {
                ForEach((0..<conductor.parameters.count), id: \.self) { i in
                    KnobAUParameterControl(auParameter: conductor.parameters[i], modulationManager: conductor.modulationManager, isLogRange: true)
                }
            } else {
                Text("No Parameters Found")
            }
            if conductor.modulations.count > 0 {
                ModulationAssignmentView(modulationManager: conductor.modulationManager)
            }
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
