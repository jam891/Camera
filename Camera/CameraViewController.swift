//
//  CameraViewController.swift
//  Camera
//
//  Created by Vitaliy Delidov on 7/18/16.
//  Copyright © 2016 Vitaliy Delidov. All rights reserved.
//

import UIKit

import Photos
import AVFoundation

class CameraViewController: UIViewController {
    
    private var timer: NSTimer!
    private var startTime = NSTimeInterval()
    
    private var captureSession: AVCaptureSession!
    private var videoDeviceInput: AVCaptureDeviceInput!
    private var videoDataOutput: AVCaptureVideoDataOutput!
    
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    private var audioConnection: AVCaptureConnection!
    private var videoConnection: AVCaptureConnection!
    
    private var audioFormatDescription: CMFormatDescription!
    private var videoFormatDescription: CMFormatDescription!
    
    private var backgroundRecordingID: UIBackgroundTaskIdentifier = 0
    
    private let lockQueue = dispatch_queue_create("lock queue", nil)
    private let sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL)
    
    private var outputURL = NSURL(fileURLWithPath: NSString.pathWithComponents([NSTemporaryDirectory(), "output.mov"]) as String)
    
    private var isRecording = false

    private var recorder: VideoRecorder!
    

    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var indicator: UILabel!
    @IBOutlet weak var recordLabel: UILabel!
    @IBOutlet weak var backgroundImageView: UIImageView!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.presentTransparentNavigationBar()
    }
    
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        setupSession()
        setupPreview()
        startSession()
        
        updateUI()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        stopSession()
        stopRecording()
    }
    
    
    // MARK: - Session
    
    private func setupSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSessionPresetHigh
        
        captureSession.beginConfiguration()
        addVideoInput()
        addAudioInput()
        addVideoDataOutput()
        addAudioDataOutput()
        captureSession.commitConfiguration()
    }
    
    private func startSession() {
        if !captureSession.running {
            dispatch_async(sessionQueue) {
                self.captureSession.startRunning()
            }
        }
    }
    
    private func stopSession() {
        if captureSession.running {
            dispatch_async(sessionQueue) {
                self.captureSession.stopRunning()
            }
        }
    }

    
    // MARK: - Input
    
    private func addVideoInput() {
        let camera = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        var videoIn: AVCaptureDeviceInput!
        do { videoIn = try AVCaptureDeviceInput(device: camera) } catch { return }
        guard captureSession.canAddInput(videoIn) else { return }
        captureSession.addInput(videoIn)
        videoDeviceInput = videoIn
    }
    
    private func addAudioInput() {
        let mic = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio)
        var audioIn: AVCaptureDeviceInput!
        do { audioIn = try AVCaptureDeviceInput(device: mic) } catch { return }
        guard captureSession.canAddInput(audioIn) else { return }
        captureSession.addInput(audioIn)
    }
    
    // MARK: - Output
    
    private func addVideoDataOutput() {
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey : Int(kCVPixelFormatType_32BGRA)
        ]
        captureSession.addOutput(videoDataOutput)
        self.videoDataOutput = videoDataOutput
        videoConnection = videoDataOutput.connectionWithMediaType(AVMediaTypeVideo)
    }
    
    private func addAudioDataOutput() {
        let audioDataOutput = AVCaptureAudioDataOutput()
        audioDataOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        captureSession.addOutput(audioDataOutput)
        audioConnection = audioDataOutput.connectionWithMediaType(AVMediaTypeAudio)
    }
    
    // MARK: - Preview
    
    private func setupPreview() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        let statusBarOrientation = UIApplication.sharedApplication().statusBarOrientation
        var initialVideoOrientation = AVCaptureVideoOrientation.Portrait
        if statusBarOrientation != .Unknown {
            initialVideoOrientation = AVCaptureVideoOrientation(rawValue: statusBarOrientation.rawValue)!
        }
        previewLayer.connection.videoOrientation = initialVideoOrientation
        
        previewView.layer.addSublayer(previewLayer!)
    }
    
    // MARK: - Config recorder
    
    private func configRecorder() {
        recorder = VideoRecorder(outputURL: outputURL)
        recorder.setupAudioInputWithFormatDescription(audioFormatDescription)
        recorder.setupVideoInputWithFormatDescription(videoFormatDescription)
    }
    
 
    // MARK: - Actions
    
    @IBAction func changeCamera(sender: UIBarButtonItem) {
        let blurEffectView = UIVisualEffectView(frame: previewView.bounds)
        blurEffectView.effect = UIBlurEffect(style: .Dark)
        blurEffectView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        previewView.addSubview(blurEffectView)
        
        dispatch_async(sessionQueue) {
            let currentVideoDevice = self.videoDeviceInput.device
            let currentPosition = currentVideoDevice.position
            
            let preferredPosition: AVCaptureDevicePosition
            
            switch currentPosition {
            case .Unspecified, .Front:
                preferredPosition = .Back
            case .Back:
                preferredPosition = .Front
            }
            
            sender.image = preferredPosition == .Front ? UIImage(named: "front") : UIImage(named: "back")
            
            let camera = CameraViewController.deviceWithMediaType(AVMediaTypeVideo, preferringPosition: preferredPosition)
            var videoDeviceInput: AVCaptureDeviceInput!
            do { videoDeviceInput = try AVCaptureDeviceInput(device: camera) } catch { return }
            self.captureSession.beginConfiguration()
            self.captureSession.removeInput(self.videoDeviceInput)
            guard self.captureSession.canAddInput(videoDeviceInput) else { return self.captureSession.addInput(self.videoDeviceInput) }
            self.captureSession.addInput(videoDeviceInput)
            self.videoDeviceInput = videoDeviceInput
            
            self.videoConnection = self.videoDataOutput.connectionWithMediaType(AVMediaTypeVideo)
            
            dispatch_async(dispatch_get_main_queue()) {
                UIView.transitionWithView(self.previewView, duration: 0.5, options: [.AllowAnimatedContent, .TransitionFlipFromLeft], animations: {
                }) { finished in
                    self.captureSession.commitConfiguration()
                    blurEffectView.removeFromSuperview()
                }
            }
        }
    }
    
    @IBAction func startRecording(sender: UITapGestureRecognizer) {
        if isRecording {
            if UIDevice.currentDevice().multitaskingSupported {
                backgroundRecordingID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({})
            }
            stopRecording()
        } else {
            configRecorder()
            indicator.blink()
            startTimer()
            
            isRecording = true
        }
        updateUI()
    }
    
    private func stopRecording() {
        isRecording = false
        timer.invalidate()
        indicator.layer.removeAllAnimations()
        recorder.finish {
            self.recorder = nil
            self.saveMovieToCameraRoll()
        }
    }
    
    
    private func saveMovieToCameraRoll() {
        let currentBackgroundRecordingID = backgroundRecordingID
        backgroundRecordingID = UIBackgroundTaskInvalid
        
        let cleanup: dispatch_block_t = {
            do {
                try NSFileManager.defaultManager().removeItemAtURL(self.outputURL)
            } catch {}
            if currentBackgroundRecordingID != UIBackgroundTaskInvalid {
                UIApplication.sharedApplication().endBackgroundTask(currentBackgroundRecordingID)
            }
        }
        
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .Authorized else {
                cleanup()
                return
            }
            PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true
                let changeRequest = PHAssetCreationRequest.creationRequestForAsset()
                changeRequest.addResourceWithType(PHAssetResourceType.Video, fileURL: self.outputURL, options: options)
                }, completionHandler: { success, error in
                    if !success { print("Could not save movie to photo library: \(error)") }
                    cleanup()
            })
        }
    }
    
    
    // MARK: - Timer
    
    private func startTimer() {
        timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: #selector(updateTime), userInfo: nil, repeats: true)
        startTime = NSDate.timeIntervalSinceReferenceDate()
    }
    
    func updateTime() {
        let currentTime = NSDate.timeIntervalSinceReferenceDate()
        var elapsedTime = currentTime - startTime
        
        let minutes = UInt8(elapsedTime / 60.0)
        elapsedTime -= (NSTimeInterval(minutes) * 60)
        
        let seconds = UInt8(elapsedTime)
        elapsedTime -= NSTimeInterval(seconds)
        
        recordLabel.text = String(format: "00:%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Update UI
    
    private func updateUI() {
        if isRecording {
            recordLabel.text = "00:00:00"
            recordLabel.textColor = .whiteColor()
            indicator.hidden = false
        } else {
            recordLabel.text = "Record"
            recordLabel.textColor = view.tintColor
            indicator.hidden = true
        }
    }
    
    
    // MARK: - Device Configuration
    
    private class func deviceWithMediaType(mediaType: String, preferringPosition position: AVCaptureDevicePosition) -> AVCaptureDevice? {
        if let devices = AVCaptureDevice.devicesWithMediaType(mediaType) as? [AVCaptureDevice] {
            return devices.filter({ $0.position == position }).first
        }
        return nil
    }
    
    
    // MARK: - Orientation
    
    override func shouldAutorotate() -> Bool {
        return isRecording ? false : true
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return .All
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        let deviceOrientation = UIDevice.currentDevice().orientation
        guard let newVideoOrientation = videoOrientationFor(deviceOrientation) where deviceOrientation.isPortrait || deviceOrientation.isLandscape else { return }
        
        previewLayer.connection.videoOrientation = newVideoOrientation
    }
    
    
    private func videoOrientationFor(deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch deviceOrientation {
        case .Portrait: return .Portrait
        case .PortraitUpsideDown: return .PortraitUpsideDown
        case .LandscapeLeft: return .LandscapeRight
        case .LandscapeRight: return .LandscapeLeft
        default: return nil
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        previewLayer?.frame = previewView.bounds
    }
    
    
    // MARK: - image from sample buffer
    
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBufferRef) -> UIImage {
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        
        CVPixelBufferLockBaseAddress(imageBuffer, 0)
        
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedFirst.rawValue | CGBitmapInfo.ByteOrder32Little.rawValue).rawValue
        let context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, bitmapInfo)
        
        let quartzImage = CGBitmapContextCreateImage(context)
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0)
        
        let image = UIImage(CGImage: quartzImage!)
        
        return image
    }
}


// MARK: - Sample buffer delegate

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        if connection.supportsVideoOrientation { connection.videoOrientation = previewLayer.connection.videoOrientation }
        if connection.supportsVideoMirroring { connection.videoMirrored = videoDeviceInput.device.position == .Front ? true : false }
        
        if captureOutput is AVCaptureVideoDataOutput {
            let image = imageFromSampleBuffer(sampleBuffer)
            
            dispatch_async(dispatch_get_main_queue()) {
                self.backgroundImageView.image = image
            }
        }
        
        let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
        
        if connection === videoConnection {
            videoFormatDescription = formatDescription
            if isRecording {
                dispatch_sync(lockQueue) {
                    self.recorder.appendVideoSampleBuffer(sampleBuffer)
                }
            }
        }
        
        if connection === audioConnection {
            audioFormatDescription = formatDescription
            if isRecording {
                dispatch_sync(lockQueue) {
                    self.recorder.appendAudioSampleBuffer(sampleBuffer)
                }
            }
        }
    }
    
    
}
