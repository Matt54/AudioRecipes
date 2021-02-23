//
//  WavetableHelpers.swift
//  AudioRecipes
//
//  Created by Matt Pfeiffer on 2/15/21.
//

import Foundation
import AudioKit
import Accelerate

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

func downSampleTables(inputTables: [Table], numberOfOutputSamples: Int = 64) -> [Table] {
    let numberOfInputSamples = inputTables[0].content.count
    let inputLength = vDSP_Length(numberOfInputSamples)
    
    let filterLength: vDSP_Length = 2
    let filter = [Float](repeating: 1/Float(filterLength), count: Int(filterLength))
    
    let decimationFactor = numberOfInputSamples / numberOfOutputSamples
    let n = vDSP_Length((inputLength - filterLength) / vDSP_Length(decimationFactor))
    
    var outputTables : [Table] = []
    for inputTable in inputTables {
        var outputSignal = [Float](repeating: 0, count: Int(n))
        vDSP_desamp(inputTable.content,
                    decimationFactor,
                    filter,
                    &outputSignal,
                    n,
                    filterLength)
        outputTables.append(Table(outputSignal))
    }
    return outputTables
}

func chopAudioToTables(signal: [Float], tableLength: Int = 2048) -> [Table] {
    let numberOfSamples = signal.count
    let numberOfOutputTables = numberOfSamples / tableLength
    var outputTables: [Table] = []
    for i in 0...numberOfOutputTables-1 {
        let startIndex = i * tableLength
        let endIndex = startIndex + tableLength
        outputTables.append(Table(Array(signal[startIndex..<endIndex])))
    }
    
    return outputTables
}
