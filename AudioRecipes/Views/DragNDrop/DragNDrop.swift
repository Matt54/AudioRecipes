//
//  DragNDrop.swift
//  AudioRecipes
//
//  Created by Matt Pfeiffer on 3/14/21.
//

import SwiftUI

struct DragNDrop: View {
    

    var body: some View {
        VStack{
            DragableRect()
            DroppableCircle()
        }
    }
}

struct DragNDrop_Previews: PreviewProvider {
    static var previews: some View {
        DragNDrop()
    }
}

class Item: NSObject, NSItemProviderWriting {
    static var writableTypeIdentifiersForItemProvider: [String] = ["drag-rect"]
    
    func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        print("loadData")
        print(typeIdentifier)
        return .none
    }
    
    
}

struct DragableRect: View{
    let item = Item()
    let color: Color = Color.yellow
    
    var body: some View {
        Rectangle()
            .fill(color)
            .onDrag({ return NSItemProvider(object: self.item) })
    }
}

struct DroppableCircle: View {
    @State private var imageUrls: [Int: URL] = [:]
    @State private var active = 0
    
    var body: some View {
        let dropDelegate = MyDropDelegate()
        
        Circle()
            .onDrop(of: ["drag-rect"], delegate: dropDelegate)
    }
}

struct MyDropDelegate: DropDelegate {
    func performDrop(info: DropInfo) -> Bool {
        print(info)
        return true
    }
}
