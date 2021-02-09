//
//  WavetableArrayView.swift
//  AudioRecipes
//
//  Created by Macbook on 2/8/21.
//

import SwiftUI
import AudioKit
import Accelerate



struct WavetableArrayView: View {
    @StateObject var wavetableModel = WavetableModel()
    
    @State var backgroundColor = Color.black
    @State var arrayStrokeColor = Color.white.opacity(0.4)
    @State var selectedStrokeColor = Color.white.opacity(1.0)
    @State var fillColor = Color.green.opacity(0.7)
    
    var node: DynamicOscillator
    @Binding var selectedValue : Double
    @State var wavetableArray : [Table] = []
    
    var body: some View {
        let selectedIndex = Int(selectedValue)
        let xOffset = CGFloat(0.21) / CGFloat(wavetableArray.count)
        let yOffset = CGFloat(-0.77) / CGFloat(wavetableArray.count)
        
        return GeometryReader { geometry in
            ZStack {
                backgroundColor
                WavetableArrayStrokeView(wavetableArray: wavetableArray)
                
                fillAndStrokeTable(width: geometry.size.width * 0.75,
                           height: geometry.size.height * 0.2,
                           table: wavetableArray[selectedIndex].content)
                    .frame(width: geometry.size.width * 0.5,
                           height: geometry.size.height * 0.2)
                    .offset(x: CGFloat(selectedIndex) * geometry.size.width * xOffset-geometry.size.width / 4.3,
                            y: CGFloat(selectedIndex) * geometry.size.height * yOffset + geometry.size.height / 2.6)
                
                /*ForEach((0..<wavetableArray.count).reversed(), id: \.self) { i in
                    Group {
                        strokeTable(width: geometry.size.width * 0.75,
                                   height: geometry.size.height * 0.2,
                                   table: wavetableArray[i].content)
                        if i == selectedIndex {
                            fillAndStrokeTable(width: geometry.size.width * 0.75,
                                       height: geometry.size.height * 0.2,
                                       table: wavetableArray[i].content)
                        }
                        
                    }
                    .frame(width: geometry.size.width * 0.5,
                           height: geometry.size.height * 0.2)
                    .offset(x: CGFloat(i) * geometry.size.width * xOffset-geometry.size.width / 4.3,
                            y: CGFloat(i) * geometry.size.height * yOffset + geometry.size.height / 2.6)
                }*/
                
            }//.drawingGroup()
            .onAppear {
                wavetableModel.updateNode(node)
            }
        }
    }
    
    func strokeTable(width: CGFloat, height: CGFloat, table: [Float]) -> some View {
        let points : [CGPoint] = mapPoints(width: width, height: height, table: table)
        return Path{ path in
            path.addLines(points)
        }
        .stroke(arrayStrokeColor,lineWidth: 1)
    }
    
    func fillAndStrokeTable(width: CGFloat, height: CGFloat, table: [Float]) -> some View {
        let points : [CGPoint] = mapPoints(width: width, height: height, table: table, shouldClosePath: true)
        return ZStack {
            Path{ path in
                path.addLines(points)
            }
            .stroke(selectedStrokeColor,lineWidth: 1)
            
            Path{ path in
                path.addLines(points)
            }
            .fill(fillColor)
        }
    }
    
    func mapPoints(width: CGFloat, height: CGFloat, table: [Float], shouldClosePath: Bool = false) -> [CGPoint] {
        let xPaddedLowerBound = width*0.01
        let xPaddedUpperBound = width*0.99
        let yPaddedLowerBound = height*0.01
        let yPaddedUpperBound = height*0.99
        
        var points : [CGPoint] = []
        
        if shouldClosePath {
            points.append(CGPoint(x: xPaddedLowerBound,y: height*0.5))
        }
        
        for i in 0..<table.count {
            let x = i.mapped(from: 0...table.count, to: xPaddedLowerBound...xPaddedUpperBound)
            let y = CGFloat(table[i]).mapped(from: -1...1, to: yPaddedLowerBound...yPaddedUpperBound)
            points.append(CGPoint(x: x, y: height-y))
        }
        
        if shouldClosePath {
            points.append(CGPoint(x: xPaddedUpperBound,y: height*0.5))
            points.append(CGPoint(x: xPaddedLowerBound,y: height*0.5))
        }
        return points
    }
    
    struct WavetableArrayStrokeView: View {
        @State var wavetableArray : [Table] = []
        @State var arrayStrokeColor = Color.white.opacity(0.4)
        var selectedStrokeColor = Color.white.opacity(1.0)
        
        var body: some View {
            let xOffset = CGFloat(0.21) / CGFloat(wavetableArray.count)
            let yOffset = CGFloat(-0.77) / CGFloat(wavetableArray.count)
            
            return GeometryReader { geometry in
                ZStack {
                    Color.black
                    ForEach((0..<wavetableArray.count).reversed(), id: \.self) { i in
                        strokeTable(width: geometry.size.width * 0.75,
                                   height: geometry.size.height * 0.2,
                                   table: wavetableArray[i].content)
                        .frame(width: geometry.size.width * 0.5,
                               height: geometry.size.height * 0.2)
                        .offset(x: CGFloat(i) * geometry.size.width * xOffset-geometry.size.width / 4.3,
                                y: CGFloat(i) * geometry.size.height * yOffset + geometry.size.height / 2.6)
                    }
                }
            }
        }
        
        func strokeTable(width: CGFloat, height: CGFloat, table: [Float]) -> some View {
            let points : [CGPoint] = mapPoints(width: width, height: height, table: table)
            return Path{ path in
                path.addLines(points)
            }
            .stroke(arrayStrokeColor,lineWidth: 1)
        }
        
        func mapPoints(width: CGFloat, height: CGFloat, table: [Float], shouldClosePath: Bool = false) -> [CGPoint] {
            let xPaddedLowerBound = width*0.01
            let xPaddedUpperBound = width*0.99
            let yPaddedLowerBound = height*0.01
            let yPaddedUpperBound = height*0.99
            
            var points : [CGPoint] = []
            
            if shouldClosePath {
                points.append(CGPoint(x: xPaddedLowerBound,y: height*0.5))
            }
            
            for i in 0..<table.count {
                let x = i.mapped(from: 0...table.count, to: xPaddedLowerBound...xPaddedUpperBound)
                let y = CGFloat(table[i]).mapped(from: -1...1, to: yPaddedLowerBound...yPaddedUpperBound)
                points.append(CGPoint(x: x, y: height-y))
            }
            
            if shouldClosePath {
                points.append(CGPoint(x: xPaddedUpperBound,y: height*0.5))
                points.append(CGPoint(x: xPaddedLowerBound,y: height*0.5))
            }
            return points
        }
    }
    
}

struct WavetableArrayView_Previews: PreviewProvider {
    static var previews: some View {
        let testWaves : [Table] = [Table(.triangle), Table(.square), Table(.sine), Table(.sawtooth)]
        let interpolatedTestWaves = createInterpolatedTables(inputTables: testWaves)
        
        return WavetableArrayView(node: DynamicOscillator(), selectedValue: .constant(0), wavetableArray: interpolatedTestWaves)
            .frame(width: 400, height: 200)
    }
}

func createInterpolatedTables(inputTables: [Table], numberOfDesiredTables : Int = 256) -> [Table] {
    var interpolatedTables : [Table] = []
    let thresholdForExact = 0.01 * Double(inputTables.count)
    let rangeValue = (Double(numberOfDesiredTables) / Double(inputTables.count - 1)).rounded(.up)
    
    for i in 1...numberOfDesiredTables{
        let waveformIndex = Int( Double(i-1) / rangeValue)
        let interpolatedIndex = (Double(i-1) / rangeValue).truncatingRemainder(dividingBy: 1.0)
        
        // if we are nearly exactly at one of our input tables - use the input table for this index value
        if((1.0 - interpolatedIndex) < thresholdForExact){
            interpolatedTables.append(inputTables[waveformIndex+1])
        }
        else if(interpolatedIndex < thresholdForExact){
            interpolatedTables.append(inputTables[waveformIndex])
        }
        
        // between tables - interpolate
        else{
            // linear interpolate to get array of floats existing between the two tables
            let interpolatedFloats = [Float](vDSP.linearInterpolate([Float](inputTables[waveformIndex]),
                                                                        [Float](inputTables[waveformIndex+1]),
                                                                        using: Float(interpolatedIndex) ) )
            interpolatedTables.append(Table(interpolatedFloats))
        }
    }
    return interpolatedTables
}
