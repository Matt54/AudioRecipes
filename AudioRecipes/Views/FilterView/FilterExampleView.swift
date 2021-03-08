import SwiftUI

struct FilterExampleView: View {
    @EnvironmentObject var conductor: Conductor
    
    var body: some View {
        FilterView(node: conductor.filter)
        //Text("Hello world")
    }
}

struct FilterExampleView_Previews: PreviewProvider {
    static var previews: some View {
        FilterExampleView()
    }
}
