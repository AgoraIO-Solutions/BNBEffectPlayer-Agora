//
//  ViewController.swift
//  BanubaCoreSandbox
//
//  Created by Victor Privalov on 7/18/18.
//  Copyright © 2018 Banuba. All rights reserved.
//

import UIKit
import AVKit
import VideoToolbox
import MobileCoreServices
import BanubaSdk
import BanubaEffectPlayer
import AgoraRtcEngineKit

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate,
        UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    struct Defaults {
        static let renderSize: CGSize = CGSize(width: 720, height: 1280)
        static let PhotoCameraModeAspectRatio: CGFloat = 3.0 / 4.0
        static let VideoCameraModeAspectRatio: CGFloat = 9.0 / 16.0
    }

    var effects: [String] = []
    var glView: EffectPlayerView!
    
    let playerController = AVPlayerViewController()
    let sdkManager = BanubaSdkManager()
    
    var previewImage: UIImage?
    var previewImageSrc: UIImage?
    
    var binState: Bool = false
    var isFrontCamera: Bool = true
    var isPhotoMode: Bool = true
    
    var frameDurationLogger: FrameDurationLogger! = nil
    
    var agoraKit: AgoraRtcEngineKit!

    @IBOutlet weak var glViewContainer: UIView!
    @IBOutlet weak var photoButton: UIButton!
    @IBOutlet weak var videoButton: UIButton!
    @IBOutlet weak var effectsList: UICollectionView!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var toggleConnectButton: UIButton!

    @IBOutlet weak var switchCameraNote: UILabel!
    @IBOutlet weak var channelName: UITextField!

    @IBOutlet weak var localAgoraView: UIView!
    @IBOutlet weak var remoteAgoraView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.configureCameraModeUI()
        self.setupPlayer()
        sdkManager.input.startCamera()
        // Do any additional setup after loading the view, typically from a nib.
        
        let fm = FileManager.default
        let path = Bundle.main.bundlePath + "/effects"
        
        do {
            effects = try fm.contentsOfDirectory(atPath: path).filter {content in
                var isDir: ObjCBool = false
                fm.fileExists(atPath: path + "/" + content, isDirectory: &isDir)
                return isDir.boolValue
            }
        } catch {
            print("\(error)")
        }
        
        effectsList.dataSource = self
        effectsList.delegate = self
        
        effectsList.reloadData()
        
        // Agora related code
        initializeAgoraEngine()
        setupVideo()
        
        sdkManager.outputService?.startForwardingFrames(handler: { (pixelBuffer) -> Void in
            self.pushPixelBufferIntoAgoraKit(pixelBuffer: pixelBuffer)
        })
    }

    @IBAction func onStartBinButton(_ sender: Any) {
        let button = sender as! UIButton
        binState = !binState
        sdkManager.setFrameDataRecord(binState)
        
        let title = binState ? "[Stop]" : "[Record BIN]"
        button.setTitle(title, for: .normal)
    }
    
    @IBOutlet weak var frameLoggerNote: UILabel!
    
    @IBAction func onDurationButtonClicked(_ sender: UIButton) {
        if frameDurationLogger == nil {
            frameDurationLogger = FrameDurationLogger()
            sdkManager.effectPlayer?.add(frameDurationLogger as BNBFrameDurationListener)
            
            frameLoggerNote.text = "Disable frame logger"
        } else {
            sdkManager.effectPlayer?.remove(frameDurationLogger as BNBFrameDurationListener)
            frameDurationLogger.printResult()
            frameDurationLogger = nil
            
            frameLoggerNote.text = "Enable frame logger"
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
         sdkManager.startEffectPlayer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
         sdkManager.stopEffectPlayer()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    var fakePhoto = false
    func takeFakePhoto() {
        DispatchQueue.main.async { [weak self] in
            self!.fakePhoto = true;
            self!.makePhoto(0)
        }
    }
    func setupPlayer() {

        let configuration = EffectPlayerConfinguration(renderMode: .photo)

        sdkManager.setup(configuration: configuration)
        self.prepareRenderTargetLayer(.photo)
        if let layer = glView.layer as? CAEAGLLayer {
            sdkManager.setRenderTarget(layer: layer, playerConfiguration: nil)
        }
        sdkManager.effectPlayer?.setMaxFaces(2)
        
        TestHandler.setupTesting(sdkManager: sdkManager, view: self)

        // Watermark testing
//        if let watermark = UIImage(named: "watermark") {
//            let offset = CGPoint(x: 20.0, y: 10.0)
//            let watermarkInfo = WatermarkInfo(image: watermark, corner: .bottomLeft,
//                                              offset: offset, targetNormalizedWidth: 0.4)
//            sdkManager.configureWatermark(watermarkInfo)
//        }
    }
    
    func fileURL() -> URL {
        let fileManager = FileManager.default
        let fileUrl = fileManager.temporaryDirectory.appendingPathComponent("video.mp4")

        return fileUrl
    }
    
    //MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toPreview" {
            let previewController = segue.destination as! PreviewController
            previewController.image = self.previewImage
            self.previewImage = nil
            self.previewImageSrc = nil
        }
        if segue.identifier == "toPreviewInteractive" {
            let previewController = segue.destination as! InteractivePreviewController
            previewController.image = self.previewImage
            previewController.srcImage = self.previewImageSrc
            previewController.sdkManager = sdkManager
            self.previewImage = nil
            self.previewImageSrc = nil
        }
    }
    
    func presentVideoController(fileURL:URL) {
        let player = AVPlayer(url: fileURL)
        self.playerController.player = player
        self.present(self.playerController, animated: true, completion: nil)
    }
    
    //MARK: - IBActions
    @IBAction func makePhoto(_ sender: Any) {
        let makeStart = Date()
        sdkManager.stopEffectPlayer()
        
        let useInteractivePreview = true;
        
        let settings = CameraPhotoSettings(useStabilization: true, flashMode: .off)
        sdkManager.makeCameraPhoto(cameraSettings: settings, flipFrontCamera: true, srcImageHandler: {
            [weak self] (srcCVPixelBuffer) in
                var cgImage: CGImage?
                VTCreateCGImageFromCVPixelBuffer(srcCVPixelBuffer, options: nil, imageOut: &cgImage);
            
                var orient: UIImage.Orientation
        
                switch (self?.sdkManager.imageOrientationForCameraPhoto ?? .deg0) {
                case .deg0:
                    orient = UIImage.Orientation.up
                case .deg90:
                    orient = UIImage.Orientation.right
                case .deg180:
                    orient = UIImage.Orientation.down
                case .deg270:
                    orient = UIImage.Orientation.left
                default:
                    orient = UIImage.Orientation.up
                }
            
                let image = UIImage.init(cgImage: cgImage!, scale:1, orientation: orient);
                self?.previewImageSrc = image;
            }) { [weak self] (image) in
            DispatchQueue.main.async {
                if let image = image {
                    print("Process photo time \(-makeStart.timeIntervalSinceNow) s.")
                    self?.previewImage = image
                    if (self?.fakePhoto ?? false) {
                        self?.fakePhoto = false;
                        self?.sdkManager.startEffectPlayer()
                        return;
                    }
                    if (useInteractivePreview) {
                        self?.performSegue(withIdentifier: "toPreviewInteractive", sender: self)
                    } else {
                        self?.performSegue(withIdentifier: "toPreview", sender: self)
                    }
                }
            }
        }
    }
    
    @IBAction func toggleConnect(_ sender: UIButton) {
        sender.isSelected.toggle()
        if sender.isSelected {
            joinChannel()
        } else {
            leaveChannel()
        }
    }

    @IBAction func switchCamera(_ sender: Any) {
        isFrontCamera = !isFrontCamera
        
        if (isFrontCamera) {
            switchCameraNote.text = "Front camera"
        } else {
            switchCameraNote.text = "Back camera"
        }
        
        sdkManager.input.setCameraSessionType(cameraSessionType) {
            print("RorataCamera")
        }
    }

    @IBAction func switchRecordMode(_ sender: Any) {
        isPhotoMode = !isPhotoMode
        sdkManager.input.setCameraSessionType(cameraSessionType)

        configureCameraModeUI()

        sdkManager.stopEffectPlayer()
        let renderMode: EffectPlayerRenderMode = cameraSessionType.isPhotoMode ? .photo : .video
        prepareRenderTargetLayer(renderMode)
        if let layer = glView.layer as? CAEAGLLayer {
            sdkManager.setRenderTarget(layer: layer, playerConfiguration: nil)
        }
        sdkManager.startEffectPlayer()
    }
    
    @IBAction func openGallery(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.allowsEditing = true
        picker.delegate = self
        picker.modalPresentationStyle = .fullScreen
        present(picker, animated: true, completion: nil)
    }
    
    @IBAction func restartPlayer(_ sender: Any?) {
        if frameDurationLogger != nil {
            sdkManager.effectPlayer?.remove(frameDurationLogger as BNBFrameDurationListener)
            frameDurationLogger.printResult()
            frameDurationLogger = nil
            
            frameLoggerNote.text = "Enable frame logger"
        }
        
        sdkManager.destroyEffectPlayer()
        setupPlayer()
        sdkManager.input.startCamera()
        sdkManager.startEffectPlayer()
    }

    var cameraSessionType: CameraSessionType {
        if isFrontCamera {
            return isPhotoMode ? .FrontCameraPhotoSession : .FrontCameraVideoSession
        } else {
            return isPhotoMode ? .BackCameraPhotoSession : .BackCameraVideoSession
        }
    }

    private func configureCameraModeUI() {
        photoButton.isHidden = !isPhotoMode
        videoButton.isHidden = isPhotoMode
    }

    @IBAction func toggleVideo(_ sender: Any) {
        let shouldRecord = !(sdkManager.output?.isRecording ?? false)
        let hasSpace =  sdkManager.output?.hasDiskCapacityForRecording() ?? true
        
        if shouldRecord && hasSpace {
            let fileURL = self.fileURL()
            sdkManager.input.startAudioCapturing()
            sdkManager.output?.startVideoCapturing(fileURL:fileURL) { (success, error) in
                print("Done Writing: \(success)")
                if let _error = error {
                    print(_error)
                }
                self.sdkManager.input.stopAudioCapturing()
                print("voiceChanger.isConfigured:\(self.sdkManager.voiceChanger?.isConfigured ?? false)")
                guard (self.sdkManager.voiceChanger?.isConfigured ?? false) else {
                    self.presentVideoController(fileURL: fileURL)
                    return
                }
                self.sdkManager.effectPlayer?.setEffectVolume(0.0)
                self.sdkManager.voiceChanger?.process(file: fileURL, completion: { (success, error) in
                    self.sdkManager.effectPlayer?.setEffectVolume(1.0)
                    print("--- Voice Changer:[Success:\(success)][Error:\(String(describing: error))]")
                    if success {
                        DispatchQueue.main.async {
                            self.presentVideoController(fileURL: fileURL)
                        }
                    }
                })
            }
            
            self.videoButton.setImage(UIImage(named: "stop_video"), for: .normal)
        } else {
            sdkManager.output?.stopVideoCapturing(cancel: false)
            
            self.videoButton.setImage(UIImage(named: "shutter_video"), for: .normal)
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: false) {
            guard let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage else {
                return
            }
            
            let useInteractivePreview = true;
            
            self.previewImageSrc = image
            self.sdkManager.processImageData(image) { procImage in
                DispatchQueue.main.async {
                    self.previewImage = procImage
                    if (useInteractivePreview) {
                        self.performSegue(withIdentifier: "toPreviewInteractive", sender: self)
                    } else {
                        self.performSegue(withIdentifier: "toPreview", sender: self)
                    }
                }
            }
        }
    }
    
    // MARK: Collection  View
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return effects.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "effectCell",
                                                      for: indexPath) as! EffectCell
        let imgPath = Bundle.main.bundlePath + "/effects/" +  effects[indexPath.row]  + "/preview.png"
        var image = UIImage(contentsOfFile: imgPath)
        if image == nil {
            image = UIImage(named: "eyes_prod")
        }
        cell.image.image = image
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
         sdkManager.effectPlayer?.loadEffect(effects[indexPath.row])
    }

    func prepareRenderTargetLayer(_ renderMode: EffectPlayerRenderMode) {
        if (glView != nil) {
            glView.removeFromSuperview()
            glView = nil
        }

        let cameraSessionAspectRatio: CGFloat = (renderMode == .photo) ? Defaults.PhotoCameraModeAspectRatio : Defaults.VideoCameraModeAspectRatio
        let frame = calculateRenderLayerFrame(layerAspectRatio: cameraSessionAspectRatio)

        guard let effectPlayer = sdkManager.effectPlayer else { return }
        glView = EffectPlayerView(frame: frame)
        glView.effectPlayer = effectPlayer
        glView.isMultipleTouchEnabled = true
        glView.layer.contentsScale = UIScreen.main.scale
        glViewContainer.addSubview(glView)
    }
    
    private func calculateRenderLayerFrame(layerAspectRatio: CGFloat) -> CGRect {
        let screenSize = UIScreen.main.bounds.size
        let screenAspectRatio = screenSize.width / screenSize.height

        let width = (layerAspectRatio < screenAspectRatio) ? screenSize.height * layerAspectRatio : screenSize.width
        let height = (layerAspectRatio < screenAspectRatio) ? screenSize.height : screenSize.width / layerAspectRatio
        let size = CGSize(width: width, height: height)
        
        let x: CGFloat = (screenSize.width - width) / 2.0
        let y: CGFloat = (screenSize.height - height) / 2.0

        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
    
    // MARK: Agora
    
    func initializeAgoraEngine() {
        agoraKit = AgoraRtcEngineKit.sharedEngine(withAppId: AppID, delegate: self)
    }

    func setupVideo() {
        // Enable pushMode to make agoraKit waiting for pushFrame
        agoraKit.setExternalVideoSource(true, useTexture: true, pushMode: true);
        
        agoraKit.enableVideo()
        agoraKit.setVideoEncoderConfiguration(
            AgoraVideoEncoderConfiguration(
                size: AgoraVideoDimension640x360,
                frameRate: .fps15,
                bitrate: AgoraVideoBitrateStandard,
                orientationMode: .adaptative
            )
        )
    }
    
    func joinChannel() {
        if channelName.text != nil && !channelName.text!.isEmpty {
            agoraKit.setDefaultAudioRouteToSpeakerphone(true)
            agoraKit.joinChannel(byToken: Token, channelId: channelName.text!, info: nil, uid: 0) { [unowned self] (channel, uid, elapsed) -> Void in
                print("Join channel successfully. Channel: \(channel) UserId: \(uid) Elapsed: \(elapsed)")
            }
            channelName.isUserInteractionEnabled = false
            remoteAgoraView.isHidden = false
        } else {
            // Toggle the hangup button if channel text field is blank
            toggleConnectButton.isSelected.toggle()
        }
    }
    
    func leaveChannel() {
        // leave channel and end chat
        agoraKit.leaveChannel(nil)
        channelName.isUserInteractionEnabled = true
        remoteAgoraView.isHidden = true
    }
    
    func pushPixelBufferIntoAgoraKit(pixelBuffer: CVPixelBuffer) {
        let videoFrame = AgoraVideoFrame()
        videoFrame.format = 12
        videoFrame.time = CMTimeMakeWithSeconds(NSDate().timeIntervalSince1970, preferredTimescale: 1000)
        videoFrame.textureBuf = pixelBuffer
        videoFrame.rotation = 180
        self.agoraKit.pushExternalVideoFrame(videoFrame)
    }
}

class EffectCell: UICollectionViewCell {
    @IBOutlet weak var image: UIImageView!
}

extension ViewController: AgoraRtcEngineDelegate {
    // first remote video frame
    func rtcEngine(_ engine: AgoraRtcEngineKit, firstRemoteVideoDecodedOfUid uid:UInt, size:CGSize, elapsed:Int) {
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = uid
        videoCanvas.view = remoteAgoraView
        videoCanvas.renderMode = .hidden
        agoraKit.setupRemoteVideo(videoCanvas)
    }
        
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurWarning warningCode: AgoraWarningCode) {
        print("Agora WRN: \(warningCode.rawValue)")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        print("Agora ERR: \(errorCode.rawValue)")
    }
}

extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return textField.resignFirstResponder()
    }
}
