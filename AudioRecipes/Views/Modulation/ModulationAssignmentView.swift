//
//  ModulationAssignmentView.swift
//  AudioRecipes
//
//  Created by Matt Pfeiffer on 4/8/21.
//

import SwiftUI

struct ModulationAssignmentView: View {
    @State var foregroundColor = Color.green
    
    var modulationManager: ModulationManager
    
    init(modulationManager: ModulationManager){
        self.modulationManager = modulationManager
    }
    
    var body: some View {
        GeometryReader { geo in
            Rectangle()
            .overlay(
                Image(systemName: "plus.viewfinder")
                    .resizable()
                    .imageStyle(UpsizeStyle())
                    .foregroundColor(foregroundColor)
                    .frame(width: geo.size.width < geo.size.height ? geo.size.width*0.75 : geo.size.height*0.75,
                           height: geo.size.width < geo.size.height ? geo.size.width*0.75 : geo.size.height*0.75)
            )
        }
        .onTapGesture {
            modulationManager.isAssigningModulation.toggle()
        }
    }
}

struct ModulationAssignmentView_Previews: PreviewProvider {
    static var previews: some View {
        ModulationAssignmentView(modulationManager: ModulationManager(sampleRate: 44_100))
    }
}

public struct UpsizeStyle: ViewModifier {
    public func body(content: Content) -> some View { content
        .font(.system(size: 300))
        .aspectRatio(1.0, contentMode: .fit)
        .scaledToFit()
    }
}

public extension Image {
    func imageStyle<Style: ViewModifier>(_ style: Style) -> some View {
        ModifiedContent(content: self, modifier: style)
    }
}
