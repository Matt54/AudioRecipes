import SwiftUI

struct FilterExampleView: View {
    @EnvironmentObject var conductor: Conductor
    
    var body: some View {
        //FilterView(node: conductor.filter)
        FilterView2(node: conductor.filter)
    }
}

struct FilterExampleView_Previews: PreviewProvider {
    static var previews: some View {
        FilterExampleView()
    }
}
