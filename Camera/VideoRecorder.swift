//
//  VideoRecorder.swift
//  Camera
//
//  Created by Vitaliy Delidov on 7/18/16.
//  Copyright © 2016 Vitaliy Delidov. All rights reserved.
//

import UIKit
import AVFoundation

class VideoRecorder: NSObject {

    private let assetWriter: AVAssetWriter
    
    private var videoInput: AVAssetWriterInput!
    private var audioInput: AVAssetWriterInput!
    
    var width: Int32 = 300
    var height: Int32 = 300
    
    
    
    init(outputURL: NSURL) {
        assetWriter = try! AVAssetWriter(URL: outputURL, fileType: AVFileTypeQuickTimeMovie)
    }
    
    func setupAudioInputWithFormatDescription(formatDescription: CMFormatDescription) {
        let settings = [
            AVFormatIDKey : UInt(kAudioFormatMPEG4AAC)
        ]
        
        guard assetWriter.canApplyOutputSettings(settings, forMediaType: AVMediaTypeAudio) else { return }
        audioInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: settings, sourceFormatHint: formatDescription)
        audioInput!.expectsMediaDataInRealTime = true
        
        guard assetWriter.canAddInput(audioInput!) else { return }
        assetWriter.addInput(audioInput!)
    }
    
    func setupVideoInputWithFormatDescription(formatDescription: CMFormatDescription) {
        let videoSettings = [
            AVVideoCodecKey : AVVideoCodecH264,
            AVVideoWidthKey : NSNumber(int: width),
            AVVideoHeightKey : NSNumber(int: height),
            AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill
        ]
        
        guard assetWriter.canApplyOutputSettings(videoSettings, forMediaType: AVMediaTypeVideo) else { return }
        videoInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings, sourceFormatHint: formatDescription)
        videoInput.expectsMediaDataInRealTime = true
        
        guard assetWriter.canAddInput(videoInput!) else { return }
        assetWriter.addInput(videoInput!)
    }
    
    
    func appendVideoSampleBuffer(sampleBuffer: CMSampleBuffer) {
        appendSampleBuffer(sampleBuffer, ofMediaType: AVMediaTypeVideo)
    }
    
    func appendAudioSampleBuffer(sampleBuffer: CMSampleBufferRef) {
        appendSampleBuffer(sampleBuffer, ofMediaType: AVMediaTypeAudio)
    }
    
    func appendSampleBuffer(sampleBuffer: CMSampleBuffer, ofMediaType mediaType: String) {
        if CMSampleBufferDataIsReady(sampleBuffer) {
            if assetWriter.status == .Unknown {
                let startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                assetWriter.startWriting()
                assetWriter.startSessionAtSourceTime(startTime)
            }
            if assetWriter.status == .Failed {
                print(assetWriter.error!.localizedDescription)
                return
            }
            
            let input = mediaType == AVMediaTypeVideo ? videoInput : audioInput
            
            guard input.readyForMoreMediaData else { return }
            input.appendSampleBuffer(sampleBuffer)
        }
    }
    
    func finish(callback: Void -> Void) {
        assetWriter.finishWritingWithCompletionHandler(callback)
    }
}
