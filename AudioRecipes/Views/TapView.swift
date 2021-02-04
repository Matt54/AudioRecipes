//
//  TapView.swift
//  VisualizerPlayground
//
//  Created by Matt Pfeiffer on 1/28/21.
//

import SwiftUI

struct TapView: View {
    @State private var tapViewOpacity = 1.0
    var body: some View {
        HStack(spacing: 0.0){
            Image(systemName: "hand.tap.fill")
            Text("Touch to Change Variation")
        }
        .font(.headline)
        .foregroundColor(Color.white)
        .padding(10)
        .background(Color.gray)
        .cornerRadius(15)
        .opacity(tapViewOpacity)
        .animation(.linear(duration: 1.5))
        .onAppear {
            tapViewOpacity = 0.0
        }
    }
}

struct TapView_Previews: PreviewProvider {
    static var previews: some View {
        TapView()
    }
}
