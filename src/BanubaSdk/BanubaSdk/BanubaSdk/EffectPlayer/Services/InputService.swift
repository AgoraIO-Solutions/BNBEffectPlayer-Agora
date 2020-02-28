//
//  InputService.swift
//  BanubaCore
//
//  Created by Victor Privalov on 7/19/18.
//  Copyright © 2018 Banuba. All rights reserved.
//

import Accelerate
import MediaPlayer

public typealias InputServicing = CameraServicing & AudioCapturing & CameraZoomable
public typealias AVCaptureDataDelegate = AVCaptureVideoDataOutputSampleBufferDelegate & AVCaptureAudioDataOutputSampleBufferDelegate & AVCapturePhotoCaptureDelegate
public typealias RotateCameraCallBack = () -> ()

public protocol CameraServicing: AnyObject {
    var delegate: InputServiceDelegate? { get set }
    var isFrontCamera: Bool { get }
    var isPhotoCameraSession: Bool { get }
    var isCameraCapturing: Bool { get }
    var currentCameraSessionType: CameraSessionType { get }
    var exposurePointOfInterest: CGPoint { get }

    func startCamera()
    func stopCamera()
    func setCameraSessionType(_ type: CameraSessionType)
    func setCameraSessionType(_ type: CameraSessionType, completion: @escaping RotateCameraCallBack)
    func setCameraSessionType(_ type: CameraSessionType, zoomFactor: Float, completion: @escaping RotateCameraCallBack)
    func configureExposureSettings(_ point: CGPoint?, useContinuousDetection: Bool)
    func initiatePhotoCapture(cameraSettings: CameraPhotoSettings, completion: @escaping (CVImageBuffer?) -> Void)
}

public protocol AudioCapturing: AnyObject {
    func startAudioCapturing()
    func stopAudioCapturing()
}

public protocol CameraZoomable: AnyObject {
    var currentFieldOfView: Float { get }
    var isZoomFactorAdjustable: Bool { get }
    var minZoomFactor: Float { get }
    var maxZoomFactor: Float { get }
    var zoomFactor: Float { get }
    func setZoomFactor(_ zoomFactor:Float) -> Float
}

public protocol InputServiceDelegate: AnyObject {
    func push(buffer: CVPixelBuffer)
    func push(buffer: CMSampleBuffer)
}

public enum CameraSessionType {
    case FrontCameraVideoSession
    case BackCameraVideoSession
    case FrontCameraPhotoSession
    case BackCameraPhotoSession
}

public struct CameraPhotoSettings {
    public let useStabilization: Bool
    public let flashMode: AVCaptureDevice.FlashMode
    
    public init(useStabilization: Bool, flashMode: AVCaptureDevice.FlashMode) {
        self.useStabilization = useStabilization
        self.flashMode = flashMode
    }
}

public class InputService: NSObject {
    public enum InputServiceError: Error {
        case CameraDeviceInitializationFailed
        case CameraInputInitializationFailed
        case AudioDeviceInitializationFailed
        case AudioInputInitializationFailed
    }
    
    struct Defaults {
        static let videoSessionCameraPreset: AVCaptureSession.Preset = .hd1280x720
        static let photoSessionCameraPreset: AVCaptureSession.Preset = .photo
        
        static let cameraDeviceInitFailedMessage = "Camera device initialization was failed!"
        static let cameraInputInitFailedMessage = "Camera input initialization was failed!"
        static let audioDeviceInitFailedMessage = "Audio device initialization was failed!"
        static let audioInputInitFailedMessage = "Audio input initialization was failed!"
        static let changeExposureSettingsFailedMessage = "Configuring of camera exposure settings has failed!"
        static let configureAudioSessionFailedMessage = "Audio session configuration was failed!"
        
        static let audioSessionQueueLabel = "com.banubaSdk.audioSessionQueue"
        static let cameraSessionQueueLabel = "com.banubaSdk.cameraSessionQueue"
        
        static let availablePixelFormatRemapping: [OSType: [UInt8]] = [kCVPixelFormatType_32BGRA: [2, 1, 0, 3],
                                                                       kCVPixelFormatType_32ARGB: [1, 2, 3, 0],
                                                                       kCVPixelFormatType_32RGBA: [0, 1, 2, 3],
                                                                       kCVPixelFormatType_32ABGR: [3, 2, 1, 0]]
    }

    private var cameraCaptureSession: AVCaptureSession?
    private var cameraDevice: AVCaptureDevice?
    private var cameraInput: AVCaptureDeviceInput?
    private let cameraSessionQueue = DispatchQueue(label: Defaults.cameraSessionQueueLabel, qos: .userInitiated)
    
    private var cameraPhotoOutput: AVCapturePhotoOutput?
    private var cameraVideoOutput: AVCaptureVideoDataOutput?
    
    private var audioSession: AVCaptureSession?
    private var audioDevice: AVCaptureDevice?
    private var audioSessionQueue = DispatchQueue(label: Defaults.audioSessionQueueLabel, qos: .userInitiated)
    
    private var cameraSessionType: CameraSessionType
    
    private var photoCompletionHandler: ((CVImageBuffer?) -> Void)?
    private var cameraPhotoSettings: CameraPhotoSettings?
    
    public weak var delegate: InputServiceDelegate?
    
    public init(cameraMode: CameraSessionType) {
        cameraSessionType = cameraMode

        super.init()
        
        setupCameraSession(withType: cameraSessionType)
        configureAudioSessionWithCategory(.ambient)
    }
    
    deinit {
        guard let session = cameraCaptureSession else { return }

        session.stopRunning()
        
        session.inputs.forEach { (input) in
            session.removeInput(input)
        }
        session.outputs.forEach { (output) in
            session.removeOutput(output)
        }
    }
    
    public func setupCameraSession(withType type: CameraSessionType, zoomFactor: Float? = nil, completion: RotateCameraCallBack? = nil) {
        cameraSessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.configureCameraSession(type: type)
            if let zoomFactor = zoomFactor {
                let _ = self.setZoomFactor(zoomFactor)
            }
            
            completion?()
        }
    }
    
    private func configureCameraSession(type: CameraSessionType) {
        #if !TARGET_IPHONE_SIMULATOR
        if cameraCaptureSession == nil {
            cameraCaptureSession = AVCaptureSession()
        }
        guard let session = cameraCaptureSession else { return }

        let isSessionRunning = session.isRunning
        
        cameraSessionType = type
        session.beginConfiguration()
        
        session.sessionPreset = isPhotoCameraSession ? Defaults.photoSessionCameraPreset : Defaults.videoSessionCameraPreset
        
        let deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        let devicePosition:AVCaptureDevice.Position = isFrontCamera ? .front : .back
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: devicePosition)
        
        cameraDevice = discoverySession.devices.first
        guard let camera = cameraDevice else {
            session.commitConfiguration()
            print(Defaults.cameraDeviceInitFailedMessage)
            return
        }
        
        if let input = cameraInput {
            session.removeInput(input)
        }
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            session.addInput(input)
            cameraInput = input
        } catch {
            print(Defaults.cameraInputInitFailedMessage)
        }

        let photoOutput = defaultPhotoSessionOutput()
        if session.canAddOutput(photoOutput) {
            if let previousPhotoOutput = cameraPhotoOutput {
                session.removeOutput(previousPhotoOutput)
            }
            session.addOutput(photoOutput)
            cameraPhotoOutput = photoOutput
        }
        
        let videoOutput = defaultVideoSessionOutput()
        if let previousVideoOutput = cameraVideoOutput {
            session.removeOutput(previousVideoOutput)
        }
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            if let captureConnection = videoOutput.connection(with: .video) {
                captureConnection.videoOrientation = .portrait
                captureConnection.isVideoMirrored = isFrontCamera
            }
            cameraVideoOutput = videoOutput
        }

        session.commitConfiguration()
        
        // If capture session was running before, we should ensure that it still running after reconfiguration,
        // because sometimes device could stop session after applying new settings (very unstable and rare issue).
        if isSessionRunning {
            startCamera()
        }
        #endif // !TARGET_IPHONE_SIMULATOR
    }
    
    private func setupAudioCaptureSessionIfNeeded() {
        guard audioSession == nil else { return }
        
        let session = AVCaptureSession()
        session.usesApplicationAudioSession = false
        audioSession = session
        
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        
        let deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInMicrophone]
        let discoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: deviceTypes, mediaType: .audio, position: .unspecified)
        audioDevice = discoverySession.devices.first
        
        guard let audio = audioDevice else {
            print(Defaults.audioDeviceInitFailedMessage)
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: audio)
            session.addInput(input)
        } catch {
            print(Defaults.audioInputInitFailedMessage)
        }
        
        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        session.addOutput(output)
    }

    private func defaultPhotoSessionOutput() -> AVCapturePhotoOutput {
        let photoOutput = AVCapturePhotoOutput()
        photoOutput.isHighResolutionCaptureEnabled = true
        return photoOutput
    }
    
    private func defaultVideoSessionOutput() -> AVCaptureVideoDataOutput {
        let videoOutput = AVCaptureVideoDataOutput()
        
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey) : kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .default))
        
        return videoOutput
    }

    var lastValue: CMTimeValue = 0
    var duplicatesSampleBuffer = false
}

extension InputService: AVCaptureDataDelegate {

    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output is AVCaptureAudioDataOutput {
            let currentValue = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).value
            if lastValue != currentValue {
                lastValue = currentValue

                if !duplicatesSampleBuffer {
                    delegate?.push(buffer: sampleBuffer)
                }
            } else {
                duplicatesSampleBuffer = true
                delegate?.push(buffer: sampleBuffer)
            }

        } else if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            delegate?.push(buffer: pixelBuffer)
        }
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // handle sampleBuffer drops ?
    }
    
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingRawPhoto rawSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        handlePhotoCapturing(sampleBuffer: rawSampleBuffer, error: error)
    }
    
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        handlePhotoCapturing(sampleBuffer: photoSampleBuffer, error: error)
    }
    
    private func handlePhotoCapturing(sampleBuffer: CMSampleBuffer?, error: Error?) {
        defer {
            photoCompletionHandler = nil
        }

        guard error == nil, let imageSample = sampleBuffer, let imageBuffer = CMSampleBufferGetImageBuffer(imageSample) else {
            photoCompletionHandler?(nil)
            return
        }
        photoCompletionHandler?(imageBuffer)
    }
}

extension InputService: InputServicing {
    
    public func configureExposureSettings(_ point: CGPoint?, useContinuousDetection: Bool) {
        guard let camera = cameraDevice else { return }
        
        var convertedPoint: CGPoint? = nil
        if let initialPoint = point {
            convertedPoint = convertToExposurePoint(initialPoint, isFrontCamera: isFrontCamera)
        }
        
        do {
            try camera.lockForConfiguration()
            
            let exposureMode: AVCaptureDevice.ExposureMode = useContinuousDetection ? .continuousAutoExposure : .autoExpose
            if (camera.isExposurePointOfInterestSupported && camera.isExposureModeSupported(exposureMode)) {
                camera.exposurePointOfInterest = convertedPoint ?? camera.exposurePointOfInterest
                camera.exposureMode = exposureMode
            }
            
            camera.unlockForConfiguration()
        } catch {
            print(Defaults.changeExposureSettingsFailedMessage)
        }
    }
    
    /// Initial value uses a coordinate system where {0,0} is the top left of the picture area and {1,1} is the bottom right.
    /// Device exposure point coordinate system is always relative to a landscape device orientation
    /// with the home button on the right, regardless of the actual device orientation.
    /// So, correct translation will be - (x = y, y = 1 - x)
    /// Also, on front camera we should flip x component again, because we're processing mirrored image - (x = y, y = x)
    private func convertToExposurePoint(_ point: CGPoint, isFrontCamera: Bool) -> CGPoint {
        let convertedY = isFrontCamera ? point.x : 1.0 - point.x
        return CGPoint(x: point.y, y: convertedY)
    }
    
    public var exposurePointOfInterest: CGPoint {
        guard let camera = cameraDevice else { return CGPoint.zero }
        return camera.exposurePointOfInterest
    }
    
    public var currentFieldOfView: Float {
        guard let camera = cameraDevice else { return 0.0 }
        return Float(camera.activeFormat.videoFieldOfView)
    }

    public var isZoomFactorAdjustable: Bool {
        return abs(maxZoomFactor - minZoomFactor) > .ulpOfOne
    }
    
    public var minZoomFactor: Float {
        return 1.0
    }
    
    public var maxZoomFactor: Float {
        guard let camera = cameraDevice else { return minZoomFactor }
        return Float(camera.activeFormat.videoMaxZoomFactor)
    }
    
    public var zoomFactor: Float {
        guard let camera = cameraDevice else { return minZoomFactor }
        return Float(camera.videoZoomFactor)
    }

    public func setZoomFactor(_ zoomFactor: Float) -> Float {
        guard let camera = cameraDevice else { return minZoomFactor }
        
        if isZoomFactorAdjustable {
            let correctedZoomFactor = max(minZoomFactor, min(zoomFactor, maxZoomFactor))
            
            do {
                try camera.lockForConfiguration()
                camera.videoZoomFactor = CGFloat(correctedZoomFactor)
                camera.unlockForConfiguration()
                
                return correctedZoomFactor
            } catch {
                return minZoomFactor
            }
        } else {
            return minZoomFactor
        }
    }
    
    public func startCamera() {
        cameraSessionQueue.async { [weak self] in
            guard let self = self, let session = self.cameraCaptureSession else { return }

            session.startRunning()
        }
    }
    
    public func stopCamera() {
        cameraSessionQueue.async { [weak self] in
            guard let self = self, let session = self.cameraCaptureSession else { return }

            session.stopRunning()
        }
    }

    public func initiatePhotoCapture(cameraSettings: CameraPhotoSettings, completion: @escaping (CVImageBuffer?) -> Void) {
        guard isPhotoCameraSession, let device = cameraDevice else {
            completion(nil)
            return
        }

        cameraPhotoSettings = cameraSettings
        photoCompletionHandler = completion

        if device.isReadyToMakePhoto {
            makePhoto(cameraPhotoSettings: cameraSettings)
        } else {
            startObservingCameraAdjusting()
        }
    }
    
    private func makePhoto(cameraPhotoSettings: CameraPhotoSettings) {
        guard isPhotoCameraSession, let photoOutput = cameraPhotoOutput else {
            photoCompletionHandler?(nil)
            return
        }
        
        let supportedPixelFormats = Defaults.availablePixelFormatRemapping.keys.filter { photoOutput.availablePhotoPixelFormatTypes.contains($0) }
        guard let pixelFormat = supportedPixelFormats.first else {
            // We can't find any suitable pixel format for further processing
            photoCompletionHandler?(nil)
            return
        }
        
        let settings = AVCapturePhotoSettings(pixelFormat: pixelFormat, cameraPhotoSettings: cameraPhotoSettings)
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    public var isPhotoCameraSession: Bool {
        return cameraSessionType == .BackCameraPhotoSession || cameraSessionType == .FrontCameraPhotoSession
    }
    
    public var isFrontCamera: Bool {
        return cameraSessionType == .FrontCameraPhotoSession || cameraSessionType == .FrontCameraVideoSession
    }
    
    public var isCameraCapturing: Bool {
        guard let session = cameraCaptureSession else { return false }

        return session.isRunning
    }
    
    public var currentCameraSessionType: CameraSessionType {
        return cameraSessionType
    }
    
    public func setCameraSessionType(_ type: CameraSessionType, completion: @escaping RotateCameraCallBack) {
        guard cameraSessionType != type else { return }
        
        setupCameraSession(withType: type) {
            completion()
        }
    }
    
    public func setCameraSessionType(_ type: CameraSessionType) {
        guard cameraSessionType != type else { return }

        setupCameraSession(withType: type)
    }
    
    public func setCameraSessionType(_ type: CameraSessionType, zoomFactor: Float, completion: @escaping RotateCameraCallBack) {
        guard cameraSessionType != type else { return }
        
        setupCameraSession(withType: type, zoomFactor: zoomFactor) {
            completion()
        }
    }
    
    public func startAudioCapturing() {
        audioSessionQueue.async { [weak self] in
            self?.setupAudioCaptureSessionIfNeeded()

            guard let session = self?.audioSession else { return }

            session.startRunning()
        }
    }
    
    public func stopAudioCapturing() {
        audioSessionQueue.async { [weak self] in
            guard let session = self?.audioSession else { return }

            session.stopRunning()
            self?.configureAudioSessionWithCategory(.ambient)
            self?.duplicatesSampleBuffer = false
        }
    }
    
    private func configureAudioSessionWithCategory(_ category: AVAudioSession.Category) {
        let audioSharedSession = AVAudioSession.sharedInstance()
        do {
            try audioSharedSession.setCategory(category, mode: .default, options: .mixWithOthers)
            try audioSharedSession.setActive(true)
        } catch {
            print(Defaults.configureAudioSessionFailedMessage)
        }
    }
}

extension AVCapturePhotoSettings {
    convenience init(pixelFormat: OSType, cameraPhotoSettings: CameraPhotoSettings) {
        self.init(format: [String(kCVPixelBufferPixelFormatTypeKey) : pixelFormat])
        
        flashMode = cameraPhotoSettings.flashMode
        isAutoStillImageStabilizationEnabled = cameraPhotoSettings.useStabilization
        isHighResolutionPhotoEnabled = true
    }
}

// Camera adjusting before making photo (using KVO)
extension InputService {
    private static var observingContext = 0
    
    struct ObservingKeys {
        static let adjustingWhiteBalanceKeyPath = "adjustingWhiteBalance"
        static let adjustingFocusKeyPath = "adjustingFocus"
        static let adjustingExposureKeyPath = "adjustingExposure"
    }
    
    func startObservingCameraAdjusting() {
        guard let device = cameraDevice else { return }
        
        device.addObserver(self, forKeyPath: ObservingKeys.adjustingWhiteBalanceKeyPath, options: [.old, .new], context: &InputService.observingContext)
        device.addObserver(self, forKeyPath: ObservingKeys.adjustingFocusKeyPath, options: [.old, .new], context: &InputService.observingContext)
        device.addObserver(self, forKeyPath: ObservingKeys.adjustingExposureKeyPath, options: [.old, .new], context: &InputService.observingContext)
    }
    
    func stopObservingCameraAdjusting() {
        guard let device = cameraDevice else { return }
        
        device.removeObserver(self, forKeyPath: ObservingKeys.adjustingWhiteBalanceKeyPath)
        device.removeObserver(self, forKeyPath: ObservingKeys.adjustingFocusKeyPath)
        device.removeObserver(self, forKeyPath: ObservingKeys.adjustingExposureKeyPath)
    }
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context != &InputService.observingContext {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        guard isPhotoCameraSession,
            let device = cameraDevice,
            let settings = cameraPhotoSettings else { return }
        
        if device.isReadyToMakePhoto {
            stopObservingCameraAdjusting()
            
            DispatchQueue.main.async { [weak self] in
                self?.makePhoto(cameraPhotoSettings: settings)
            }
        }
    }
}

extension CameraSessionType {
    public var isFrontCamera: Bool {
        return self == .FrontCameraPhotoSession || self == .FrontCameraVideoSession
    }
    
    public var isPhotoMode: Bool {
        return self == .BackCameraPhotoSession || self == .FrontCameraPhotoSession
    }
}

fileprivate extension AVCaptureDevice {
    var isReadyToMakePhoto: Bool {
        return !isAdjusting
    }
    
    private var isAdjusting: Bool {
        return adjustingProperties.isContainsTrue
    }
    
    private var adjustingProperties: [Bool] {
        return [isAdjustingFocus, isAdjustingExposure, isAdjustingWhiteBalance]
    }
}

fileprivate extension Array where Element == Bool {
    var isContainsTrue: Bool {
        let firstTrue = first(where: { $0 == true })
        return firstTrue != nil
    }
}
