
import UIKit
import Accelerate
import BanubaEffectPlayer

public protocol OutputServicing: AnyObject {
    func takeSnapshot(handler:@escaping (UIImage?)->Void)
    func takeSnapshot(configuration: OutputConfiguration, handler:@escaping (UIImage?)->Void)
    func configureWatermark(_ watermarkInfo: WatermarkInfo)
    func removeWatermark()
    func startVideoCapturing(fileURL:URL?, completion:@escaping (Bool, Error?)->Void)
    func startVideoCapturing(fileURL:URL?, configuration: OutputConfiguration, completion:@escaping (Bool, Error?)->Void)
    func stopVideoCapturing(cancel:Bool)

    func startForwardingFrames(handler: @escaping (CVPixelBuffer) -> Void)
    func stopForwardingFrames()
    func reset()
    func hasDiskCapacityForRecording() -> Bool

    func startMuteEffectSoundIfNeeded()
    func stopMuteEffectSound()

    var isRecording: Bool { get }
    var videoSize: CGSize { get set }
    var cropOffsetY: Int { get set }
}

public class OutputConfiguration {
    public let applyWatermark: Bool
    public let adjustDeviceOrientation: Bool
    public let mirrorFrontCamera: Bool
    
    public init(applyWatermark: Bool, adjustDeviceOrientation: Bool, mirrorFrontCamera: Bool) {
        self.applyWatermark = applyWatermark
        self.adjustDeviceOrientation = adjustDeviceOrientation
        self.mirrorFrontCamera = mirrorFrontCamera
    }
    
    public static var defaultConfiguration: OutputConfiguration {
        return OutputConfiguration(applyWatermark: false,
                                   adjustDeviceOrientation: false,
                                   mirrorFrontCamera: true)
    }
}

public class OutputService {
    struct Defaults {
        static let pixelBufferWriterLimit = 30
        static let pixelBufferPoolInitialSize = 3
        static let targetPixelFormat = kCVPixelFormatType_32BGRA
        static let availablePixelFormatRemapping: [OSType: [UInt8]] = [kCVPixelFormatType_32BGRA: [2, 1, 0, 3],
                                                                       kCVPixelFormatType_32ARGB: [1, 2, 3, 0],
                                                                       kCVPixelFormatType_32RGBA: [0, 1, 2, 3],
                                                                       kCVPixelFormatType_32ABGR: [3, 2, 1, 0]]
    }
    
    public var videoSize: CGSize {
        didSet {
            if oldValue != videoSize {
                videoWriter = nil
                pixelBufferPool = nil

                if let watermarkInfo = watermarkInfo,
                    let _ = watermarkPixelBuffer {
                    
                    configureWatermark(watermarkInfo)
                }
            }
        }
    }

    public var cropOffsetY: Int = 0

    private var watermarkInfo: WatermarkInfo?
    private var watermarkOutputSettings: OutputSettings?

    var snapshotHandler : ((UIImage?)->Void)?
    var frameHandler : ((CVPixelBuffer)->Void)?

    public var synchronousVideoCapturing = false
    public private (set) var isRecording = false

    private var snapshotOutputSettings: OutputSettings? = nil
    private var videoOutputSettings: OutputSettings? = nil
    private var videoWriter: SBVideoWriter?
    private var pixelBufferPool: CVPixelBufferPool?
    private let queue: OperationQueue
    private let fileManager = FileManager.default
    private let effectPlayer: BNBEffectPlayer
    private let input: InputServicing
    
    private var watermarkPixelBuffer: CVPixelBuffer?

    init(effectPlayer: BNBEffectPlayer, input: InputServicing, queue:OperationQueue, videoSize: CGSize) {
        self.queue = queue
        self.videoSize = videoSize
        self.effectPlayer = effectPlayer
        self.input = input
    }

    func removeFile(fileURL:URL) {
        if fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
        }
    }
}

extension OutputService: OutputServicing {
    public func startForwardingFrames(handler: @escaping (CVPixelBuffer) -> Void) {
      self.frameHandler = handler
    }

    public func stopForwardingFrames() {
      self.frameHandler = nil
    }

    public func reset() {
        videoWriter = nil
        isRecording = false
    }

    public func configureWatermark(_ watermarkInfo: WatermarkInfo) {
        configureWatermark(watermarkInfo, configuration: OutputConfiguration.defaultConfiguration)
    }
    
    private func configureWatermark(_ watermarkInfo: WatermarkInfo, configuration: OutputConfiguration) {
        self.watermarkInfo = watermarkInfo
        let watermarkSettings = makeOutputSettings(configuration)
        watermarkOutputSettings = watermarkSettings
        
        watermarkPixelBuffer = createWatermarkPixelBuffer(watermarkInfo: watermarkInfo,
                                                          targetSize: self.videoSize,
                                                          targetPixelFormat: Defaults.targetPixelFormat,
                                                          outputSettings: watermarkSettings)
    }

    public func removeWatermark() {
        watermarkPixelBuffer = nil
        watermarkInfo = nil
    }

    public func takeSnapshot(handler:@escaping (UIImage?)->Void) {
        takeSnapshot(configuration: OutputConfiguration.defaultConfiguration, handler: handler)
    }
    
    public func takeSnapshot(configuration: OutputConfiguration, handler: @escaping (UIImage?) -> Void) {
        snapshotOutputSettings = makeOutputSettings(configuration)
        adjustWatermarkIfNeeded(newConfiguration: configuration)
        
        snapshotHandler = { (snapshot) in
            DispatchQueue.main.async {
                handler(snapshot)
            }
        }
    }

    public func startVideoCapturing(fileURL:URL?, completion:@escaping (Bool, Error?)->Void) {
        startVideoCapturing(fileURL: fileURL, configuration: OutputConfiguration.defaultConfiguration,
                            completion: completion)
    }
    
    public func startVideoCapturing(fileURL: URL?, configuration: OutputConfiguration,
                                    completion: @escaping (Bool, Error?) -> Void) {
        queue.addOperation { [weak self] in
            guard let self = self else { return }
            
            if let url = fileURL, self.videoWriter == nil {
                self.removeFile(fileURL: url)
                
                self.adjustWatermarkIfNeeded(newConfiguration: configuration)
                
                let settings = self.makeOutputSettings(configuration)
                self.videoOutputSettings = settings
                
                self.videoWriter = SBVideoWriter(size: self.videoSize, outputSettings: settings)
                self.videoWriter?.prepareInputs(url)
            }
            
            guard !self.isRecording, let writer = self.videoWriter else { return }
            self.isRecording = true

            writer.startCapturingScreen { [weak self] (success, error) in
                self?.videoWriter = nil

                DispatchQueue.main.async {
                    completion(success, error)
                }
            }
        }
    }
    
    public func stopVideoCapturing(cancel:Bool) {
        queue.addOperation { [weak self] in
            guard let self = self else { return }
            
            defer { self.isRecording = false }
            
            guard let writer = self.videoWriter, self.isRecording else { return }
            
            if cancel {
                writer.discardCapturing()
                self.videoWriter = nil
            } else {
                writer.stopCapturing()
            }
        }
    }
    
    public func startMuteEffectSoundIfNeeded() {
        effectPlayer.onVideoRecordStart()
    }

    public func stopMuteEffectSound() {
        effectPlayer.onVideoRecordEnd()
    }

    public func hasDiskCapacityForRecording() -> Bool {
        return SBVideoWriter.isEnoughDiskSpaceForRecording()
    }

}

//MARK: - Handlers
extension OutputService {

    func handle(snapshotProvider provider:SnapshotProvider) {
        guard let handler = snapshotHandler, let settings = snapshotOutputSettings else { return }
        
        defer {
            snapshotHandler = nil
            snapshotOutputSettings = nil
        }
        
        let watermarkBuffer = settings.applyWatermark ? watermarkPixelBuffer : nil
        let image = provider.makeSnapshotWithSettings(settings, watermarkPixelBuffer: watermarkBuffer)
        handler(image)
    }

    func handle(bufferProvider provider:PixelBufferProvider) {
        guard let pixelBuffer = provider.makeVideoPixelBuffer() else { return }
        
        if let frameHandler = self.frameHandler {
            frameHandler(pixelBuffer)
        } else {
            guard let writer = self.videoWriter, isRecording else { return }
            
            guard let bufferPool = self.preparePixelBufferPool(sourceBuffer: pixelBuffer),
                let processedBuffer = prepareVideoPixelBuffer(sourceBuffer: pixelBuffer, pixelBufferPool: bufferPool) else { return }

            if queue.operationCount < Defaults.pixelBufferWriterLimit {
                queue.addOperation {
                    writer.pushVideoSampleBuffer(processedBuffer)
                }
            }
        }
    }

    private func makeOutputSettings(_ configuration: OutputConfiguration) -> OutputSettings {
        let orientation = configuration.adjustDeviceOrientation ? BanubaSdkManager.currentDeviceOrientation : .portrait
        let isMirrored = configuration.mirrorFrontCamera && input.isFrontCamera
        
        return OutputSettings(orientation: orientation,
                              isMirrored: isMirrored,
                              applyWatermark: configuration.applyWatermark)
    }
    
    private func preparePixelBufferPool(sourceBuffer: CVPixelBuffer) -> CVPixelBufferPool? {
        guard pixelBufferPool == nil else { return pixelBufferPool }

        let pixelFormat = CVPixelBufferGetPixelFormatType(sourceBuffer)
        let width = self.videoSize.width
        let height = self.videoSize.height

        let pixelBufferPoolOptions: NSDictionary = [kCVPixelBufferPoolMinimumBufferCountKey: Defaults.pixelBufferPoolInitialSize]
        let sourcePixelBufferOptions: NSDictionary = [kCVPixelBufferPixelFormatTypeKey: pixelFormat,
                                                      kCVPixelBufferWidthKey: width,
                                                      kCVPixelBufferHeightKey: height,
                                                      kCVPixelFormatOpenGLESCompatibility: true,
                                                      kCVPixelBufferIOSurfacePropertiesKey: NSDictionary()]

        CVPixelBufferPoolCreate(kCFAllocatorDefault, pixelBufferPoolOptions, sourcePixelBufferOptions, &pixelBufferPool)

        return pixelBufferPool
    }

    private func prepareVideoPixelBuffer(sourceBuffer: CVPixelBuffer, pixelBufferPool: CVPixelBufferPool) -> CVPixelBuffer? {
        
        func applyFlipTransformations(bufferInfo: inout vImage_Buffer, settings: OutputSettings) {
            if settings.shouldApplyVerticalFlip {
                vImageVerticalReflect_ARGB8888(&bufferInfo, &bufferInfo, UInt32(kvImageNoFlags))
            }
            if settings.shouldApplyHorizontalFlip {
                vImageHorizontalReflect_ARGB8888(&bufferInfo, &bufferInfo, UInt32(kvImageNoFlags))
            }
        }
        
        // Source pixel buffer, which we receive from provider (BNBRenderTarget in our case), is based on GL texture cache, so it's basically reuses the same memory area.
        // So, before using this buffer for video writing, we need to copy it, because otherwise we can write malformed data
        // (when video recording is slowed down, and memory is overwritten by next render pass).
        //
        // Also, since video is rendered upside down (GL uses inverted coordinate system), here we rotate it back manually.
        // Performance note - on slowest devices (iPhone 5S) whole process (create new pixelbuffer + copy + flip) takes up to 2.5-3 ms, on newer devices - <1.0 ms.

        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &buffer)

        guard let resultBuffer = buffer, let outputSettings = videoOutputSettings else { return nil }

        CVPixelBufferLockBaseAddress(sourceBuffer, [])
        CVPixelBufferLockBaseAddress(resultBuffer, [])
        defer {
            CVPixelBufferUnlockBaseAddress(resultBuffer, [])
            CVPixelBufferUnlockBaseAddress(sourceBuffer, [])
        }

        let src = CVPixelBufferGetBaseAddress(sourceBuffer)
        let dst = CVPixelBufferGetBaseAddress(resultBuffer)
        
        let width = UInt(videoSize.width)
        let height = UInt(videoSize.height)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(sourceBuffer)
        let offset = (cropOffsetY) * bytesPerRow

        // If user configured watermark previously, we should apply it right now.
        // vImagePremultipliedAlphaBlend_BGRA8888 leaves bottom and top data unchanged, and places result into destination
        if let watermark = watermarkPixelBuffer, outputSettings.applyWatermark {
            let watermarkWidth = UInt(CVPixelBufferGetWidth(watermark))
            let watermarkHeight = UInt(CVPixelBufferGetHeight(watermark))

            if (watermarkWidth == width) && (watermarkHeight == height) {
                CVPixelBufferLockBaseAddress(watermark, [])

                let watermarkAddress = CVPixelBufferGetBaseAddress(watermark)
                let watermarkBytesPerRow = CVPixelBufferGetBytesPerRow(watermark)

                var srcBufferInfo = vImage_Buffer(data: src?.advanced(by: offset), height: height, width: width, rowBytes: bytesPerRow)
                var dstBufferInfo = vImage_Buffer(data: dst, height: height, width: width, rowBytes: bytesPerRow)
                var watermarkBufferInfo = vImage_Buffer(data: watermarkAddress, height: watermarkHeight, width: watermarkWidth, rowBytes: watermarkBytesPerRow)

                applyFlipTransformations(bufferInfo: &srcBufferInfo, settings: outputSettings)
                
                vImagePremultipliedAlphaBlend_BGRA8888(&watermarkBufferInfo, &srcBufferInfo, &dstBufferInfo, UInt32(kvImageNoFlags))

                CVPixelBufferUnlockBaseAddress(watermark, [])

                return resultBuffer
            }
        }

        memcpy(dst, src?.advanced(by: offset), Int(height) * bytesPerRow)

        var bufferInfo = vImage_Buffer(data: dst, height: height, width: width, rowBytes: bytesPerRow)
        applyFlipTransformations(bufferInfo: &bufferInfo, settings: outputSettings)

        return resultBuffer
    }

    func handle(audioBuffer buffer:CMSampleBuffer) {
        queue.addOperation { [weak self] in
            guard let self = self, let writer = self.videoWriter, self.isRecording else { return }
            
            writer.pushAudioSampleBuffer(buffer)
        }
    }
    
    private func adjustWatermarkIfNeeded(newConfiguration: OutputConfiguration) {
        guard newConfiguration.applyWatermark, let watermarkInfo = watermarkInfo else { return }
        
        let newSettings = makeOutputSettings(newConfiguration)
        
        var shouldRecreate = true
        if let settings = watermarkOutputSettings, settings.deviceOrientation == newSettings.deviceOrientation {
            shouldRecreate = false
        }
        
        if shouldRecreate {
            removeWatermark()
            configureWatermark(watermarkInfo, configuration: newConfiguration)
        }
    }

    private func createWatermarkPixelBuffer(watermarkInfo: WatermarkInfo, targetSize: CGSize, targetPixelFormat: OSType, outputSettings: OutputSettings) -> CVPixelBuffer? {
        guard let cgImage = watermarkInfo.image.cgImage,
            Defaults.availablePixelFormatRemapping.keys.contains(targetPixelFormat) else { return nil }

        let bufferWidth = Int(targetSize.width)
        let bufferHeight = Int(targetSize.height)

        var pixelBuffer:CVPixelBuffer? = nil
        let status = CVPixelBufferCreate(kCFAllocatorDefault, bufferWidth, bufferHeight, targetPixelFormat, nil, &pixelBuffer)

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        //----------draw from image to pixelbuffer (image source has RGBA channels)
        CVPixelBufferLockBaseAddress(buffer, [])

        let bufferData = CVPixelBufferGetBaseAddress(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: cgImage.alphaInfo.rawValue)
        let graphicContext = CGContext(data: bufferData, width: bufferWidth, height: bufferHeight, bitsPerComponent: 8,
                                bytesPerRow: bytesPerRow, space: rgbColorSpace, bitmapInfo: bitmapInfo.rawValue)

        guard let context = graphicContext else { return nil }

        let drawSettings = watermarkInfo.drawSettingsWithBoundsSize(targetSize, outputSettings: outputSettings)
        
        context.translateBy(x: drawSettings.translatePos.x, y: drawSettings.translatePos.y)
        context.rotate(by: drawSettings.rotationAngle)
        
        UIGraphicsPushContext(context)
        
        context.draw(cgImage, in: drawSettings.drawRect)

        CVPixelBufferUnlockBaseAddress(buffer, [])

        //----------permute channels in result pixelbuffer, if targetPixelFormat differs from RGBA (image source)
        guard targetPixelFormat != kCVPixelFormatType_32RGBA,
            let pixelFormatRemapper = Defaults.availablePixelFormatRemapping[targetPixelFormat] else { return buffer }

        CVPixelBufferLockBaseAddress(buffer, [])

        let resultData = CVPixelBufferGetBaseAddress(buffer)

        var bufferInfo = vImage_Buffer(data: resultData, height: UInt(bufferHeight), width: UInt(bufferWidth), rowBytes: bytesPerRow)
        vImagePermuteChannels_ARGB8888(&bufferInfo, &bufferInfo, pixelFormatRemapper, UInt32(kvImageNoFlags))

        CVPixelBufferUnlockBaseAddress(buffer, [])
        UIGraphicsPopContext()

        return buffer
    }
}

private extension DispatchQueue {
    func execute(_ workItem: DispatchWorkItem, sync: Bool) {
        if sync {
            self.sync(execute: workItem)
        } else {
            self.async(execute: workItem)
        }
    }
}
