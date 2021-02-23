//
//  AudioAnalysisHelpers.swift
//  AudioRecipes
//
//  Created by Matt Pfeiffer on 2/15/21.
//

import Foundation
import AVFoundation
import Accelerate

func loadAudioSignal(audioURL: URL) -> (signal: [Float], rate: Double, frameCount: Int) {
    let file = try! AVAudioFile(forReading: audioURL)
    let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: file.fileFormat.channelCount, interleaved: false)
    let buf = AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: UInt32(file.length))
    try! file.read(into: buf!)
    let floatArray = Array(UnsafeBufferPointer(start: buf!.floatChannelData![0], count:Int(buf!.frameLength)))
    return (signal: floatArray, rate: file.fileFormat.sampleRate, frameCount: Int(file.length))
}

func createRMSAnalysisArray(signal: [Float], windowSize: Int) -> [Float] {
    let numberOfSamples = signal.count
    let numberOfOutputArrays = numberOfSamples / windowSize
    var outputArray: [Float] = []
    for i in 0...numberOfOutputArrays-1 {
        let startIndex = i * windowSize
        let endIndex = startIndex + windowSize >= signal.count ? signal.count-1 : startIndex + windowSize
        let arrayToAnalyze = Array(signal[startIndex..<endIndex])
        var rms: Float = 0
        vDSP_rmsqv(arrayToAnalyze, 1, &rms, UInt(windowSize))
        outputArray.append(rms)
    }
    return outputArray
}

func createRMSAnalysisArray(signal: [Float], windowSize: Int) -> ContiguousArray<Float> {
    let numberOfSamples = signal.count
    let numberOfOutputArrays = numberOfSamples / windowSize
    var outputArray = ContiguousArray<Float>()
    for i in 0...numberOfOutputArrays-1 {
        let startIndex = i * windowSize
        let endIndex = startIndex + windowSize >= signal.count ? signal.count-1 : startIndex + windowSize
        let arrayToAnalyze = Array(signal[startIndex..<endIndex])
        var rms: Float = 0
        vDSP_rmsqv(arrayToAnalyze, 1, &rms, UInt(windowSize))
        outputArray.append(rms)
    }
    return outputArray
}


