//
//  ViewController.swift
//  OffscreenTestApp
//
//  Created by martsinkevich on 12/11/18.
//  Copyright © 2018 Banuba. All rights reserved.
//

import UIKit
import AVFoundation
import BNBEffectPlayer

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var imageView: UIImageView!
    var session: AVCaptureSession?
    
    var effectPlayer: BNBOffscreenEffectPlayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        effectPlayer = BNBOffscreenEffectPlayer.init(directories: nil, effectWidth: 720, andHeight: 1280)
        
        session = AVCaptureSession()
        session!.beginConfiguration();
        session!.sessionPreset = .hd1280x720
        
        let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .front)
        var error: NSError?
        var input: AVCaptureDeviceInput!
        do {
            input = try AVCaptureDeviceInput(device: camera!)
        } catch let error1 as NSError {
            error = error1
            input = nil
            print(error!.localizedDescription)
        }
        
        if error == nil && session!.canAddInput(input) {
            session!.addInput(input)
        }
        
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey:kCVPixelFormatType_32BGRA] as [String:Any]
        
        output.setSampleBufferDelegate(self, queue: DispatchQueue.global())
        
        
        session?.addOutput(output)
        
        
        let conn = output.connection(with: .video)
        conn?.videoOrientation = .portrait
        conn?.isVideoMirrored = true
        
        session?.commitConfiguration()
        
        session?.startRunning()
    }
    
    func imageFromData(data : inout Data, width : Int, height : Int) -> UIImage
    {
        var image: UIImage?;
        
        data.withUnsafeMutableBytes { (data : UnsafeMutablePointer<UInt8>) -> Void in
            let colorSpace = CGColorSpaceCreateDeviceRGB();
            var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Little.rawValue
            bitmapInfo |= CGImageAlphaInfo.premultipliedFirst.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
            let context = CGContext.init(data: data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo)
            let quartzImage = context?.makeImage();
            image = UIImage.init(cgImage: quartzImage!);
        }
        
        return image!;
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        CVPixelBufferLockBaseAddress(imageBuffer!, [])
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer!)
        let width = CVPixelBufferGetWidth(imageBuffer!)
        let height = CVPixelBufferGetHeight(imageBuffer!)
        let src_buff = CVPixelBufferGetBaseAddress(imageBuffer!)
        
        let data = Data(bytes: src_buff!, count: bytesPerRow * height)
        
        var format = EpImageFormat(
            cameraSize : CGSize(width: width, height: height),
            screenSize: CGSize.zero,
            orientation: .angles0,
            isMirrored: false,
            fov: 0,
            isYFlip: false)
        
        var processedData = effectPlayer?.processImage(data, with: &format)
        
        let image = imageFromData(data: &processedData!, width: 720, height: 1280)
        
        DispatchQueue.main.async {
            self.imageView.image = image
        }

        CVPixelBufferUnlockBaseAddress(imageBuffer!, [])
    }
}

