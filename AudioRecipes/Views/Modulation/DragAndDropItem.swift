//
//  DragAndDropItem.swift
//  AudioRecipes
//
//  Created by Matt Pfeiffer on 4/7/21.
//

import Foundation
import SwiftUI

final class DragAndDropItem : NSObject, NSItemProviderWriting, NSItemProviderReading {
    static var readableTypeIdentifiersForItemProvider: [String] {return ["public.data"]}
    static var writableTypeIdentifiersForItemProvider: [String] {return ["public.data"]}
    
    var modulationAssignment: ModulationAssignment
    
    init(_modulationAssignment: ModulationAssignment) {
        modulationAssignment = _modulationAssignment
    }
    
    func loadData(withTypeIdentifier typeIdentifier: String,
                  forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        
        do{
            let data = try JSONEncoder().encode(modulationAssignment)
            completionHandler(data, nil)
        } catch{
            completionHandler(nil, error)
        }
        
        return Progress(totalUnitCount: 100)
    }
    
    static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self {
        let item = try JSONDecoder().decode(ModulationAssignment.self, from: data)
        return Self.init(_modulationAssignment: item)
    }
}

class ModulationAssignment : Codable {
    var modulationIndex: Int
    
    init(index: Int) {
        modulationIndex = index
    }
}


