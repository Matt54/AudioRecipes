//
//  ModulationDragView.swift
//  AudioRecipes
//
//  Created by Matt Pfeiffer on 4/7/21.
//

import SwiftUI

struct ModulationDragView: View {
    @State var foregroundColor = Color.white
    
    var modulationManager: ModulationManager
    var selectedModulation: Modulation? {
        didSet {
            dragAndDropItem = DragAndDropItem(_modulationAssignment: ModulationAssignment(index: modulationManager.selectedModulationIndex))
        }
    }
    
    var dragAndDropItem: DragAndDropItem = DragAndDropItem(_modulationAssignment: ModulationAssignment(index: 0))
    
    init(modulationManager: ModulationManager){
        self.modulationManager = modulationManager
        if let modulation = modulationManager.selectedModulation {
            selectedModulation = modulation
        }
    }
    
    var body: some View {
        return GeometryReader { geo in
            Rectangle()
            .overlay(
                Image(systemName: "plus.viewfinder")
                    .resizable()
                    .foregroundColor(foregroundColor)
                    .font(.system(size: 300))
                    .aspectRatio(1.0, contentMode: .fit)
                    .scaledToFit()
                    .frame(width: geo.size.width < geo.size.height ? geo.size.width*0.75 : geo.size.height*0.75,
                           height: geo.size.width < geo.size.height ? geo.size.width*0.75 : geo.size.height*0.75)
            )
            .onDrag({
                // Is this hanging the modulation thread somehow? Or the whole system?
                NSItemProvider(object: dragAndDropItem)
            })
        }
        
    }
    
}

struct ModulationDragView_Previews: PreviewProvider {
    static var previews: some View {
        ModulationDragView(modulationManager: ModulationManager(sampleRate: 44_100))
    }
}
