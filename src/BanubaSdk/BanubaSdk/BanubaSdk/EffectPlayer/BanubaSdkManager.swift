import Foundation
import BanubaEffectPlayer
import UIKit

public class BanubaSdkManager {
    
    public private(set) var effectPlayer: BNBEffectPlayer?
    
    /**
     * Face orintation in frame (degrees).
     */
    public var faceOrientation: Int?

    struct Defaults {
        static let NothingToDraw = Int64(-1)
        
        // Delay in ms after switching camera session preset, before starting to adjust camera settings.
        // (Otherwise camera device won't recognize that all needed properties needs to be adjusted).
        static let CameraDeviceInitializationDelay = 10
        static let standardVideoSize = CGSize(width: 720, height: 1280)
    }

    public private(set) var voiceChanger: VoiceChangeable?

    lazy var inputService: InputServicing = {
        if let configuration = currentEffectPlayerConfiguration {
            return InputService(cameraMode: configuration.cameraMode)
        }
        // Front photo camera mode by default, if we have no configuration at the moment
        return InputService(cameraMode: .FrontCameraPhotoSession)
    }()

    public var input: InputServicing  {
        get {
            return inputService
        }
        set {
            inputService = newValue
            inputService.delegate = self
        }
    }

    public private(set) var outputService: OutputService?

    public var output: OutputServicing?  {
        return outputService
    }

    private lazy var pushFrameSynchronizationQueue = DispatchQueue(
        label: "com.banuba.sdk.frame-synchronization-queue",
        qos: .userInitiated
    )

    //MARK: - GL
    private let context = EAGLContext(api: .openGLES3)!
    
    private var currentEffectPlayerConfiguration: EffectPlayerConfinguration?
    public var renderTarget:RenderTarget?
    
    internal class var currentDeviceOrientation: UIDeviceOrientation {
        return deviceOrientationHandler.deviceOrientation
    }
    
    public var playerConfiguration: EffectPlayerConfinguration? {
        return currentEffectPlayerConfiguration
    }
    
    public func setRenderTarget(layer: CAEAGLLayer, renderMode: EffectPlayerRenderMode, surfaceScale: CGFloat = UIScreen.main.scale) {
        // During reconfiguration on setRenderTarget videoSize and paths params aren't used, so we can leave them non-initialized.
        let newConfiguration = EffectPlayerConfinguration(renderMode: renderMode, surfaceScale: surfaceScale)
        setRenderTarget(layer: layer, playerConfiguration: newConfiguration)
    }
    
    public func setRenderTarget(layer: CAEAGLLayer, playerConfiguration: EffectPlayerConfinguration?) {
        // If we didn't provided new configuration, let's use current one as source for renderSize value.
        currentEffectPlayerConfiguration = playerConfiguration ?? currentEffectPlayerConfiguration
        
        currentEffectPlayerConfiguration?.fov = inputService.currentFieldOfView

        if let configuration = currentEffectPlayerConfiguration {
            let surfaceSize = CGSize(width: ceil(layer.bounds.size.width * configuration.surfaceScale),
                                     height: ceil(layer.bounds.size.height * configuration.surfaceScale))

            renderTarget = RenderTarget(context: self.context, layer: layer, renderSize: surfaceSize)

            renderRunLoop.renderQueue.async { [weak self] in
                self?.surfaceCreated(width: Int32(surfaceSize.width), height: Int32(surfaceSize.height))
                self?.outputService?.videoSize = surfaceSize
                self?.effectPlayer?.setEffectSize(
                    /* fxWidth: */ Int32(ceil(configuration.renderSize.width)),
                    fxHeight: Int32(ceil(configuration.renderSize.height))
                )
                self?.effectPlayer?.setCameraFov(Double(configuration.fov))
            }
        }
    }
    
    public func removeRenderTarget() {
        stopRenderLoop()
        renderRunLoop.renderQueue.async { [weak self] in
            self?.surfaceDestroyed()
            self?.renderTarget = nil
        }
    }
    
    //MARK: - Device Orientation
    private static let deviceOrientationHandler = OrientationHandler()
    private var deviceOrientation = UIDeviceOrientation.portrait
    
    //MARK: - Render RunLoop
    private var renderRunLoop : DisplayLinkRunLoop!
    
    private var editingImageFrameData: BNBFrameData?
    private var editingImageSize: CGSize?
    private var pushSize: CGSize?;
    private var surfaceSize: CGSize?;
    
    private func setupRenderRunLoop() {
        renderRunLoop = DisplayLinkRunLoop(label: "com.banubaSdk.renderQueue") { [weak self] in
            guard let `self` = self else { return false }
            return self.drawToContext()
        };
    }
    public var renderQueue : DispatchQueue {
        return renderRunLoop.renderQueue
    }
    
    private func startRenderLoop() {
        let framerate = currentEffectPlayerConfiguration?.preferredRenderFramerate ??
            EffectPlayerConfinguration.Defaults.defaultFramerate
        renderRunLoop.isStoped = false
        renderRunLoop.start(framerate: framerate)
    }
    
    private func stopRenderLoop() {
        renderRunLoop.isStoped = true
    }
    
    //MARK: - App State Handling
    public var shouldAutoStartOnEnterForeground = false
    private var appStateHandler: AppStateHandler!
    private func setupAppStateHandler() {
        self.appStateHandler.add(name: UIApplication.didEnterBackgroundNotification) { [weak self] (_) in
            guard let self = self, self.isLoaded else { return }

            self.stopEffectPlayer()
        }

        self.appStateHandler.add(name: UIApplication.willEnterForegroundNotification) { [weak self] (_) in
            guard let self = self, self.isLoaded, self.shouldAutoStartOnEnterForeground else { return }

            self.startEffectPlayer()
        }

        self.appStateHandler.add(name: UIApplication.willTerminateNotification) { [weak self] (_) in
            self?.input.stopCamera()
            self?.destroyEffectPlayer()
            
            BanubaSdkManager.deinitialize()
        }
    }
    
    //MARK: - Effect Player life circle
    public private(set) var isLoaded = false
    public init() {
        setupRenderRunLoop()
    }
    
    /**
     * Intialize common banuba SDK resources. This must be called before `BanubaSdkManger` instance
     * creation. Counterpart `deinitialize` exists.
     *
     * - parameter clientToken: name of the file with client authentication token placed in MainBundle
     * - parameter resourcePath: paths to cutom resources folders
     * - parameter logLevel: log level
     */
    public class func initialize(resourcePath: [String] = [], clientTokenPath: String, logLevel: BNBSeverityLevel = .info) {
        let mainResFolder = Bundle.init(for: BNBEffectPlayer.self).bundlePath + "/bnb-res-ios"
        let dirs = [mainResFolder] + resourcePath

        let filepath = Bundle.main.path(forResource: "client_token", ofType: "")!
        let clientToken = try! String(contentsOfFile: filepath).trimmingCharacters(in: .whitespacesAndNewlines)

        BNBUtilityManager.initialize(dirs, clientToken: clientToken);
        BNBUtilityManager.setLogLevel(logLevel)
    }
    
    /** Release common Banuba SDK resources */
    public class func deinitialize() {
        BNBUtilityManager.release()
    }
    
    deinit {
        inputService.stopCamera()
        if isLoaded {
            stopEffectPlayer()
            destroyEffectPlayer()
        }
    }
    
    func setupOutputService() {
        addSnapshotHandler { [weak self] (provider) in
            self?.outputService?.handle(snapshotProvider: provider)
        }
        
        addPixelBufferHandler { [weak self] (provider) in
            self?.outputService?.handle(bufferProvider: provider)
        }
    }
    
    public func setup(configuration: EffectPlayerConfinguration) {
        appStateHandler = AppStateHandler(notificationCenter: configuration.notificationCenter)
        setupAppStateHandler()
        
        setupOutputService()
        shouldAutoStartOnEnterForeground = configuration.shouldAutoStartOnEnterForeground
        currentEffectPlayerConfiguration = configuration
        
        inputService.delegate = self

        renderRunLoop.renderQueue.sync(flags: .barrier) {
            initPlayer(configuration: configuration)
            isLoaded = true
        }
    }
    
    public func destroy() {
        stopOrientationDetection()

        pushFrameSynchronizationQueue.sync(flags: .barrier) {
            isLoaded = false
        }
        
        inputService.delegate = nil

        //ALL listeners must be removed to avoid reference cycle!!
        effectPlayer?.remove(self as BNBCameraPoiListener)
        effectPlayer?.remove(self as BNBFaceNumberListener)
        
        EAGLContext.setCurrent(context)
        effectPlayer?.playbackStop()
        if (surfaceSize != nil) {
            surfaceDestroyed();
        }
        effectPlayer = nil
    }

}

//MARK: - Orientation Helper
private extension BanubaSdkManager {
    func startOrientationDetection() {
        BanubaSdkManager.deviceOrientationHandler.start()
    }
    
    func stopOrientationDetection() {
        BanubaSdkManager.deviceOrientationHandler.stop()
    }
}

extension BanubaSdkManager: InputServiceDelegate {
    public func push(buffer: CMSampleBuffer) {
        guard isLoaded else { return }
        self.outputService?.handle(audioBuffer: buffer)
    }
    
    public func push(buffer: CVPixelBuffer) {
        self.updateOrientationAndPush(frameBuffer: buffer)
    }
}

//MARK: Frame data capture
extension BanubaSdkManager {
    public func setFrameDataRecord(_ isRecord: Bool) {
        if isRecord {
            let datetimeFmt = DateFormatter()
            datetimeFmt.dateFormat = "yyyy-MM-dd_hh-mm-ss"
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            let filename = "frames_capture_ios_" + datetimeFmt.string(from: Date()) + ".bin"
            
            effectPlayer?.startFramedataCapture(documentsPath, filename: filename)
        }
        else {
            effectPlayer?.stopFramedataCapture()
        }
        
    }
}

//MARK: - Drawing And Capturing
extension BanubaSdkManager {
    
    func updateOrientationAndPush(frameBuffer buffer:CVPixelBuffer) {
        guard isLoaded else { return }
        // TODO: Check performace here.
        // self.deviceOrientationHelper.deviceOrientation get value Sync from other queue
        //
        let isChanged = deviceOrientation != BanubaSdkManager.deviceOrientationHandler.deviceOrientation
        if isChanged, let angle = BanubaSdkManager.deviceOrientationHandler.deviceOrientation.effectsPlayerAngle {
            deviceOrientation = BanubaSdkManager.deviceOrientationHandler.deviceOrientation
            faceOrientation = angle
        }
        //
        pushFrame(frameBuffer: buffer)
    }
    
    func addSnapshotHandler(handler:@escaping ((SnapshotProvider)->Void)) {
        renderRunLoop.addPostRender { [weak self] in
            handler((self?.renderTarget!)!)
        }
    }
    
    func addPixelBufferHandler(handler:@escaping ((PixelBufferProvider)->Void)) {
        renderRunLoop.addPostRender { [weak self] in
            handler((self?.renderTarget!)!)
        }
    }
    
    private func drawToContext() -> Bool {
        guard !renderRunLoop.isStoped, let renderTarget = self.renderTarget else {
            return false
        }
        renderTarget.activate()
        
        var needToPresentBuffer: Int64?
        if let customFrameData = editingImageFrameData {
            needToPresentBuffer = effectPlayer?.draw(withExternalFrameData: customFrameData)
        } else {
//            if let pushSize = pushSize, let surfaceSize = surfaceSize {
//                effectPlayer?.setRenderTransform(BNBPixelRect(x: 0, y: 0, w: Int32(pushSize.width), h: Int32(pushSize.height)), viewportRect: BNBPixelRect(x: Int32(surfaceSize.width/3), y: Int32(surfaceSize.height/3), w: Int32(surfaceSize.width/2), h: Int32(surfaceSize.height/2)), xFlip: false, yFlip: false);
//            }
            
            needToPresentBuffer = effectPlayer?.draw()
        }
        
        if needToPresentBuffer == Defaults.NothingToDraw {
            return false
        }
        renderTarget.presentRenderbuffer()
        return true
    }
    
}

//MARK: - Effect Player Management

extension BanubaSdkManager {
    
    public func startEffectPlayer() {
        if (!self.renderRunLoop.isStoped) {
            return
        }
        startOrientationDetection()
        renderRunLoop.renderQueue.sync {
            effectPlayer?.playbackPlay();
            startRenderLoop()
        }
    }
    
    public func stopEffectPlayer() {
        stopOrientationDetection()
        stopRenderLoop()
        renderRunLoop.renderQueue.sync {
            effectPlayer?.playbackPause();
            // Stop render loop explicitly from queue, because previous task on render queue could start it,
            // and we can get mismatch in logic state (player is stopped, but render loop is not)
            stopRenderLoop()
        }
    }
    
    public func destroyEffectPlayer() {
        stopRenderLoop()
        removeRenderTarget()
        renderRunLoop.renderQueue.sync {
            effectPlayer?.playbackPause();
            destroy()
        }
    }
    
    /// Image editing mode - renders effect on single frame prepared from image, applies effect on image in full resolution.
    ///
    /// Workflow to use editing:
    ///  - Configure effect player with correct render target and render size to match aspect ratio of edited image (could be done with setRenderTarget call), load needed effect.
    /// Pay attention that render size could be less than original image size (moreover, bigger resolution could cause performance issues), the only restriction is to preserve aspect ratio.
    ///  - Call startEditingImage. Completion block returns is any face found or not. From that moment image with applied effect is rendered on provided render target.
    ///  - Call captureEditedImage to get edited image with applied effect in fullsize resolution.
    ///  - Call stopEditingImage. After that moment user can switch to other render target and restore previous logic (push frames from camera), if needed.
    public func startEditingImage(_ image: UIImage,
                                  recognizerIterations: UInt? = nil,
                                  imageOrientation: BNBCameraOrientation = .deg0,
                                  requireMirroring: Bool = false,
                                  faceOrientation: Int = 0,
                                  resetEffect: Bool = false,
                                  processParams: BNBProcessImageParams = BNBProcessImageParams(acneProcessing: false, acneUserAreas: nil),
                                  completion: ((Int, CGRect) -> Void)? = nil) {
        guard isLoaded, let frameBuffer = image.makeBgraPixelBuffer() else {
            completion?(0, .zero)
            return
        }
        
        stopRenderLoop()
        inputService.stopCamera()
        
        renderRunLoop.renderQueue.async { [weak self] in
            autoreleasepool {
                guard let self = self else { return }
                
                self.editingImageSize = image.size
                
                self.renderTarget?.activate()
                self.effectPlayer?.startVideoProcessing(Int64(image.size.width), screenHeight: Int64(image.size.height),
                                                        orientation: imageOrientation, resetEffect: resetEffect)
                
                let fullImageData = BNBFullImageData(frameBuffer, cameraOrientation: imageOrientation,
                                                     requireMirroring: requireMirroring, faceOrientation: faceOrientation)
                self.editingImageFrameData = self.effectPlayer?.processVideoFrame(fullImageData, params: processParams,
                                                                                  recognizerIterations: recognizerIterations as NSNumber?)
                self.effectPlayer?.stopVideoProcessing(resetEffect)
                
                self.startRenderLoop()

                guard let frxResult = self.editingImageFrameData?.getFrxRecognitionResult() else {
                    completion?(0, .zero)
                    return
                }

                var faceRect: CGRect = .zero

                let faces = frxResult.getFaces()
                let facesCount = faces.filter { $0.hasFace() }.count

                if let faceInfo = faces.first {
                    let t = BNBTransformation.makeData(frxResult.getTransform().basisTransform);
                    let facePixelRect = t!.inverseJ()!.transform(faceInfo.getFaceRect())
                    faceRect = CGRect(x: Double(facePixelRect.x), y: Double(facePixelRect.y),
                                      width: Double(facePixelRect.w), height: Double(facePixelRect.h))
                }

                completion?(facesCount, faceRect)
            }
        }
    }
    
    public func captureEditedImage(imageOrientation: BNBCameraOrientation = .deg0,
                                   resetEffect: Bool = false,
                                   completion: @escaping (UIImage?) -> Void) {
        guard isLoaded, let frameData = editingImageFrameData, let imageSize = editingImageSize else {
            completion(nil)
            return
        }
        
        stopRenderLoop()
        
        renderRunLoop.renderQueue.async { [weak self] in
            autoreleasepool {
                guard let self = self else { return }
                
                self.renderTarget?.activate()
                self.effectPlayer?.startVideoProcessing(Int64(imageSize.width), screenHeight: Int64(imageSize.height),
                                                        orientation: imageOrientation, resetEffect: resetEffect)
                
                var image: UIImage? = nil
                
                if let imageData = self.effectPlayer?.drawVideoFrame(frameData, timeNs: 0, outputPixelFormat: .rgba) {
                    image = UIImage(rgbaDataNoCopy: imageData as NSData,
                                    width: Int(imageSize.width),
                                    height: Int(imageSize.height))
                }
                
                self.effectPlayer?.stopVideoProcessing(resetEffect)
                self.startRenderLoop()
                
                completion(image)
            }
        }
    }
    
    public func stopEditingImage(startCameraInput: Bool = false) {
        guard isLoaded else { return }
        
        stopRenderLoop()
        
        renderRunLoop.renderQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.editingImageSize = nil
            self.editingImageFrameData = nil
            
            self.startRenderLoop()
        }
        
        if startCameraInput {
            inputService.startCamera()
        }
    }
    
    public func makeCameraPhoto(cameraSettings: CameraPhotoSettings, flipFrontCamera: Bool = false, srcImageHandler: ((CVPixelBuffer) -> Void)? = nil, completion: @escaping (UIImage?) -> Void) {
        guard inputService.isPhotoCameraSession else {
            completion(nil)
            return
        }

        let cameraInitDelay: DispatchTime = DispatchTime.now() + DispatchTimeInterval.milliseconds(Defaults.CameraDeviceInitializationDelay)

        DispatchQueue.main.asyncAfter(deadline: cameraInitDelay, execute: { [weak self] in

            self?.inputService.initiatePhotoCapture(cameraSettings: cameraSettings, completion: { (cvImageBuffer) in
                guard let self = self,
                    let imageBuffer = cvImageBuffer else {
                        completion(nil)
                        return
                }
    
                srcImageHandler?(imageBuffer)

                let width = UInt(CVPixelBufferGetWidth(imageBuffer))
                let height = UInt(CVPixelBufferGetHeight(imageBuffer))
                
                // Frontal camera already makes mirrored photo, so if user wants non-mirrored photo (flipFrontCamera is set to false),
                // we should mirror it again. For other cases we shouldn't do anything.
                let isMirrored = self.inputService.isFrontCamera && !flipFrontCamera
                
                self.processImageData(imageBuffer, width: width, height: height, orientation: self.imageOrientationForCameraPhoto, faceOrientation: 0,
                                      isMirrored: isMirrored, completion: { (image) in
                                        
                                        CVPixelBufferUnlockBaseAddress(imageBuffer, [])
                                        completion(image)
                })
            })
        })
    }
    
    public func processImageData(
        _ inputData: CVImageBuffer,
        width: UInt,
        height: UInt,
        orientation: BNBCameraOrientation = .deg0,
        faceOrientation: Int = 0,
        isMirrored: Bool = false,
        completion: @escaping (UIImage?) -> Void
    ) {
        stopRenderLoop()
        renderQueue.async { [weak self] in

            self?.renderTarget?.activate()

            let outputData = self?.effectPlayer?.processImage(
                BNBFullImageData(
                    inputData,
                    cameraOrientation: orientation,
                    requireMirroring: isMirrored,
                    faceOrientation: faceOrientation
                ),
                outputPixelFormat: .rgba,
                params: BNBProcessImageParams(acneProcessing: false, acneUserAreas:nil)
            )

            let swapSizes = orientation == .deg90 || orientation == .deg270
            let targetWidth = swapSizes ? height : width
            let targetHeight = swapSizes ? width : height

            let processedImage = UIImage(rgbaDataNoCopy: outputData! as NSData, width: Int(targetWidth), height: Int(targetHeight))
            
            completion(processedImage)
        }
    }
    
    public func processImageData(
        _ imputImage: UIImage,
        orientation: BNBCameraOrientation = .deg0,
        isMirrored: Bool = false,
        params: BNBProcessImageParams = BNBProcessImageParams(acneProcessing: false, acneUserAreas:nil),
        completion: @escaping (UIImage?) -> Void
    ) {
        stopRenderLoop()
        renderQueue.async { [weak self] in
            autoreleasepool {
                self?.renderTarget?.activate()
                let imgProcessStart = DispatchTime.now()
                
                let width = Int(imputImage.size.width)
                let height = Int(imputImage.size.height)
                
                guard let data = imputImage.makeBgraPixelBuffer() else {
                    completion(nil)
                    return
                }
                
                guard let processed = self?.effectPlayer?.processImage(
                    BNBFullImageData(
                        data,
                        cameraOrientation: orientation,
                        requireMirroring: isMirrored,
                        faceOrientation: 0
                    ),
                    outputPixelFormat: .rgba,
                    params: params
                    ) else {
                        completion(nil)
                        return
                }
                
                let procImage = UIImage(rgbaDataNoCopy: processed as NSData, width: width,
                                        height: height)
                
                let processTime = (DispatchTime.now().uptimeNanoseconds -
                    imgProcessStart.uptimeNanoseconds) / UInt64(1E6)
                print("Process image took \(processTime) ms")
                completion(procImage)
            }
        }
    }

    public func configureWatermark(_ watermarkInfo: WatermarkInfo) {
        outputService?.configureWatermark(watermarkInfo)
    }

    public func removeWatermark() {
        outputService?.removeWatermark()
    }

    public func startVideoProcessing(
        width: UInt,
        height: UInt,
        orientation: BNBCameraOrientation = .deg0,
        resetEffect: Bool = false
    ) {
        stopRenderLoop()
        renderQueue.async { [weak self] in
            self?.effectPlayer?.playbackPlay()
            self?.effectPlayer?.startVideoProcessing(Int64(width),
                screenHeight: Int64(height),
                orientation: orientation,
                resetEffect: resetEffect)
        }
    }
    
    public func stopVideoProcessing(resetEffect: Bool = false) {
        stopRenderLoop()
        renderQueue.async { [weak self] in
            self?.effectPlayer?.stopVideoProcessing(resetEffect)
        }
    }
    
    public func processVideoFrame(
        from: CVPixelBuffer,
        to: CVPixelBuffer,
        timeNs: Int64,
        iterations: Int? = nil,
        cameraOrientation: BNBCameraOrientation = .deg0,
        requireMirroring: Bool = false,
        faceOrientation: Int = 0,
        processImageParams: BNBProcessImageParams = BNBProcessImageParams(acneProcessing: false,
            acneUserAreas: nil)
    ) {
        renderQueue.sync {
            guard let effectPlayer = effectPlayer else { return }
        
            let image = BNBFullImageData(from,
                cameraOrientation: cameraOrientation,
                requireMirroring: requireMirroring,
                faceOrientation: faceOrientation)
        
            // TODO ep.processVideoFrameAllocated
            let fd = effectPlayer.processVideoFrame(image,
                params: processImageParams,
                recognizerIterations: iterations as NSNumber?)
            
            autoreleasepool {
                let processed = effectPlayer.drawVideoFrame(fd,
                    timeNs: timeNs,
                    outputPixelFormat: .bgra)
                
                // For debug:
                // let uiImage = UIImage(rgbaDataNoCopy: processed as NSData, width: outW, height: outH)
             
                let lockRwFlag = CVPixelBufferLockFlags(rawValue: 0)
                CVPixelBufferLockBaseAddress(to,  lockRwFlag)
                defer { CVPixelBufferUnlockBaseAddress(to, lockRwFlag) }
                
                guard let rwAddress = CVPixelBufferGetBaseAddress(to) else {
                    fatalError("CVPixelBufferGetBaseAddress resturned zero")
                }
                let outW = CVPixelBufferGetWidth(to)
                let outH = CVPixelBufferGetHeight(to)
                let outCount = CVPixelBufferGetDataSize(to)
                
                if processed.count == outCount {
                    // no paddings in CVPixelBuffer
                    processed.copyBytes(to: rwAddress.assumingMemoryBound(to: UInt8.self),
                        count: outCount)
                } else {
                    let rowSize = CVPixelBufferGetBytesPerRow(to)
                    for r in 0 ..< outH {
                        let advance = rowSize * r
                        let range =  r * (outW * 4) ..< (r + 1) * (outW * 4)
                        processed.copyBytes(to:
                            rwAddress.advanced(by: advance).assumingMemoryBound(to: UInt8.self),
                            from: range)
                    }
                }
            }
        }
    }

    // After making photo iOs camera produces image rotated CCW by 90 degrees,
    // so we should map device orientation onto image orientation for processing
    public var imageOrientationForCameraPhoto: BNBCameraOrientation {
        switch deviceOrientation {
        case .portrait:
            return .deg90
        case .portraitUpsideDown:
            return .deg270
        case .landscapeLeft:
            return inputService.isFrontCamera ? .deg0 : .deg180
        case .landscapeRight:
            return inputService.isFrontCamera ? .deg180 : .deg0
        default:
            return .deg90
        }
    }
}

//MARK: - Wrapper Wrapping Private
private extension BanubaSdkManager {
    
    func initPlayer(configuration: EffectPlayerConfinguration) {
        EAGLContext.setCurrent(context)

        effectPlayer = BNBEffectPlayer.create(
            BNBEffectPlayerConfiguration(
                fxWidth: Int32(configuration.renderSize.width),
                fxHeight: Int32(configuration.renderSize.height),
                nnEnable: BNBNnMode.automatically,
                faceSearch: BNBFaceSearchMode.good,
                jsDebuggerEnable: false
            )
        )
        
        guard let effectPlayer = effectPlayer else { return }
        
        voiceChanger = VoiceChanger(effectPlayer: effectPlayer)
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let videoSize = renderTarget?.renderSize ?? Defaults.standardVideoSize
        outputService = OutputService(
            effectPlayer: effectPlayer,
            input: input,
            queue: queue,
            videoSize: videoSize
        )
        
        effectPlayer.add(self as BNBCameraPoiListener)
        effectPlayer.add(self as BNBFaceNumberListener)
    }
    
    func pushFrame(frameBuffer buffer:CVPixelBuffer) {
        guard !renderRunLoop.isStoped else { return }

        pushFrameSynchronizationQueue.sync {
            guard isLoaded else { return }
            //TODO account pushSize for rotation
            pushSize = CVImageBufferGetDisplaySize(buffer);
            effectPlayer?.pushFrame(
                BNBFullImageData(
                    buffer,
                    cameraOrientation: currentEffectPlayerConfiguration?.orientation ?? .deg0,
                    requireMirroring: currentEffectPlayerConfiguration?.isMirrored ?? false,
                    faceOrientation: faceOrientation ?? 0
                )
            )
        }
    }
    
    func surfaceCreated(width: Int32, height: Int32) {
        surfaceSize = CGSize(width: Int(width), height: Int(height));
        EAGLContext.setCurrent(context)
        effectPlayer?.surfaceCreated(width, height: height)
    }
    
    func surfaceDestroyed() {
        surfaceSize = nil
        EAGLContext.setCurrent(context)
        effectPlayer?.surfaceDestroyed()
    }
}

private extension UIDeviceOrientation {
    var effectsPlayerAngle: Int? {
        switch self {
        case .portrait:
            return 0
        case .portraitUpsideDown:
            return 180
        case .landscapeLeft:
            return -90
        case .landscapeRight:
            return 90
        default:
            return nil
        }
    }
}


//MARK: - Effect Player callbacks
extension BanubaSdkManager: BNBCameraPoiListener {

    public func onCameraPoiChanged(_ x: Float, y: Float) {
        let point = CGPoint(x: CGFloat(x), y: CGFloat(y))
        inputService.configureExposureSettings(point, useContinuousDetection: true)
    }
}

extension BanubaSdkManager: BNBFaceNumberListener {

    public func onFaceNumberChanged(_ faceNumber: Int32) {
        if faceNumber == 0 {
            // set exposure POI to screen center when no face
            let point = CGPoint(x: 0.5, y: 0.5)
            inputService.configureExposureSettings(point, useContinuousDetection: true)
        }
    }
}
