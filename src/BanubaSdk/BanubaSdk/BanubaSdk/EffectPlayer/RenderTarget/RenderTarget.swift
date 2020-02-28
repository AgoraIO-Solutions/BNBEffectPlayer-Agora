//
//  RenderTarget.swift
//  Easy Snap
//
//  Created by Victor Privalov on 7/16/18.
//  Copyright © 2018 Banuba. All rights reserved.
//

import OpenGLES
import GLKit
import Accelerate

public protocol SnapshotProvider {
    func makeSnapshotWithSettings(_ settings: OutputSettings, watermarkPixelBuffer: CVPixelBuffer?) -> UIImage?
}

public protocol PixelBufferProvider {
    func makeVideoPixelBuffer() -> CVPixelBuffer?
}

public class RenderTarget: SnapshotProvider, PixelBufferProvider {
    private var context: EAGLContext
    private var layer: CAEAGLLayer
    private(set) var renderSize: CGSize
    
    private var textureCache: CVOpenGLESTextureCache?
    private var renderTarget: CVPixelBuffer?
    private var renderTexture: CVOpenGLESTexture?
    private var croppedRenderTarget: CVPixelBuffer?
    
    private var framebuffer: GLuint = 0
    private var framebuffer2: GLuint = 0
    private var colorRenderBuffer: GLuint = 0
    
    private lazy var cropSynchronizationQueue: DispatchQueue = {
        return DispatchQueue(label: "com.banuba.sdk.crop-synchronization-queue", qos: .userInitiated, attributes: .concurrent)
    }()
    
    private var _cropEdgeInsets: UIEdgeInsets = .zero
    public var cropEdgeInsets: UIEdgeInsets {
        get {
            return cropSynchronizationQueue.sync { _cropEdgeInsets }
        }
        set {
            cropSynchronizationQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else { return }
                
                self._cropEdgeInsets = newValue
                
                let ratio = self.renderSize.height / self.layer.bounds.height
                let sum = ceil((newValue.top + newValue.bottom) * ratio)
                let renderTop = ceil(newValue.top * ratio)
                let renderBottom = sum - renderTop
                
                self._renderCropEdgeInsets = UIEdgeInsets(top: renderTop, left: 0, bottom: renderBottom, right: 0)
            }
        }
    }
    
    private var _renderCropEdgeInsets: UIEdgeInsets = .zero
    public var renderCropEdgeInsets: UIEdgeInsets {
        get {
            return cropSynchronizationQueue.sync { _renderCropEdgeInsets }
        }
    }
    
    init(context: EAGLContext, layer: CAEAGLLayer, renderSize: CGSize) {
        self.context = context
        self.layer = layer
        self.renderSize = renderSize
        
        setup()
    }
    
    deinit {
        glDeleteFramebuffers(1, &framebuffer)
        glDeleteFramebuffers(1, &framebuffer2)
        glDeleteRenderbuffers(1, &colorRenderBuffer)
    }
    
    private func setup() {
        EAGLContext.setCurrent(context)
        
        let result = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, nil,
                                                  context as CVEAGLContext, nil,
                                                  &textureCache)
        if result != kCVReturnSuccess {
            assert(false, "Error at CVOpenGLESTextureCacheCreate")
        }
        
        let emptyAttributes: CFDictionary = [:] as CFDictionary
        let attributes: CFDictionary = [kCVPixelBufferIOSurfacePropertiesKey : emptyAttributes] as CFDictionary
        
        CVPixelBufferCreate(kCFAllocatorDefault, Int(renderSize.width), Int(renderSize.height),
                            kCVPixelFormatType_32BGRA, attributes, &renderTarget)
        
        guard let textureCache = textureCache, let renderTarget = renderTarget else {
            assert(false, "Error at initializing texture cache pixelbuffer for RenderTarget")
            return
        }
        
        CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, renderTarget,
                                                     nil, GLenum(GL_TEXTURE_2D), GL_RGBA,
                                                     GLsizei(renderSize.width), GLsizei(renderSize.height),
                                                     GLenum(GL_BGRA), GLenum(GL_UNSIGNED_BYTE), 0, &renderTexture)
        
        guard let renderTexture = renderTexture else {
            assert(false, "Error at initializing render texture for RenderTarget")
            return
        }
        
        glBindTexture(CVOpenGLESTextureGetTarget(renderTexture), CVOpenGLESTextureGetName(renderTexture))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))
        
        glGenFramebuffers(1, &framebuffer)
        glGenFramebuffers(1, &framebuffer2)
        
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), framebuffer)
        
        glGenRenderbuffers(1, &colorRenderBuffer)
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), colorRenderBuffer)
        
        context.renderbufferStorage(Int(GL_RENDERBUFFER), from: layer)
        glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0),
                                  GLenum(GL_RENDERBUFFER), colorRenderBuffer)
        
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), framebuffer2)
        glFramebufferTexture2D(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0),
                               GLenum(GL_TEXTURE_2D), CVOpenGLESTextureGetName(renderTexture), 0)
    }
    
    public func makeVideoPixelBuffer() -> CVPixelBuffer? {
        return renderTarget
    }
    
    public func makeSnapshotWithSettings(_ settings: OutputSettings, watermarkPixelBuffer: CVPixelBuffer?) -> UIImage? {
        activate()
        
        guard let pixelBuffer = croppedRenderedVideoPixelBuffer else { return nil }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let dataLength: CFIndex = bytesPerRow * height
        
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let data = CVPixelBufferGetBaseAddress(pixelBuffer)
        
        guard let dataPointer = data?.bindMemory(to: UInt8.self, capacity: dataLength),
            let cfData = CFDataCreateMutable(kCFAllocatorDefault, dataLength) else { return nil }
        
        CFDataAppendBytes(cfData, UnsafePointer<UInt8>(dataPointer), dataLength)
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        
        var sourceBufferInfo = vImage_Buffer(data: CFDataGetMutableBytePtr(cfData),
                                             height: UInt(height),
                                             width: UInt(width),
                                             rowBytes: bytesPerRow)
        if settings.shouldApplyVerticalFlip {
            vImageVerticalReflect_ARGB8888(&sourceBufferInfo, &sourceBufferInfo, UInt32(kvImageNoFlags))
        }
        if settings.shouldApplyHorizontalFlip {
            vImageHorizontalReflect_ARGB8888(&sourceBufferInfo, &sourceBufferInfo, UInt32(kvImageNoFlags))
        }
        
        if let watermarkBuffer = watermarkPixelBuffer {
            let watermarkWidth = CVPixelBufferGetWidth(watermarkBuffer)
            let watermarkHeight = CVPixelBufferGetHeight(watermarkBuffer)
            
            if width == watermarkWidth && height == watermarkHeight {
                CVPixelBufferLockBaseAddress(watermarkBuffer, [])
                
                var watermarkBufferInfo = vImage_Buffer(data: CVPixelBufferGetBaseAddress(watermarkBuffer),
                                                        height: UInt(height),
                                                        width: UInt(width),
                                                        rowBytes: CVPixelBufferGetBytesPerRow(watermarkBuffer))
                
                vImagePremultipliedAlphaBlend_BGRA8888(&watermarkBufferInfo, &sourceBufferInfo, &sourceBufferInfo, UInt32(kvImageNoFlags))
                
                CVPixelBufferUnlockBaseAddress(watermarkBuffer, [])
            }
        }
        
        let permuteMap: [UInt8] = [2, 1, 0, 3] // Convert to BGRA pixel format
        vImagePermuteChannels_ARGB8888(&sourceBufferInfo, &sourceBufferInfo, permuteMap, UInt32(kvImageNoFlags))
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let dataProvider = CGDataProvider(data: cfData) else { return nil }
        
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let cgImageRef = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo, provider: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        
        guard let cgImage = cgImageRef else { return nil }
        
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: settings.resultImageOrientation)
    }
    
    func activate() {
        EAGLContext.setCurrent(context)
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), framebuffer2)
    }
    
    func presentRenderbuffer() {
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), colorRenderBuffer)
        glBindFramebuffer(GLenum(GL_READ_FRAMEBUFFER), framebuffer2)
        glBindFramebuffer(GLenum(GL_DRAW_FRAMEBUFFER), framebuffer)
        
        let cropInsets = cropEdgeInsets
        if cropInsets != .zero {
            glClearColor(0.0, 0.0, 0.0, 0.0)
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        }
        
        let scale = layer.contentsScale
        let renderCropInsets = renderCropEdgeInsets
        
        glBlitFramebuffer(0, GLint(renderCropInsets.bottom), GLint(renderSize.width),
                          GLint(renderSize.height - renderCropInsets.top), 0,
                          GLint(cropInsets.bottom), GLint(layer.bounds.width * scale),
                          GLint((layer.bounds.height - cropInsets.top) * scale),
                          GLbitfield(GL_COLOR_BUFFER_BIT), GLenum(GL_LINEAR))
        context.presentRenderbuffer(Int(GL_RENDERBUFFER))
    }
    
    private var croppedRenderedVideoPixelBuffer: CVPixelBuffer? {
        guard let renderTarget = renderTarget else { return nil }
        
        let ciImage = CIImage(cvPixelBuffer: renderTarget)
        
        let renderCropInsets = renderCropEdgeInsets
        let cropRect = CGRect(x: 0, y: renderCropInsets.top, width: renderSize.width,
                              height: renderSize.height - renderCropInsets.bottom - renderCropInsets.top)
        let croppedImage = ciImage.cropped(to: cropRect)
        
        return croppedImage.pixelBuffer ?? pixelBufferFromCIImage(croppedImage)
    }
    
    private func pixelBufferFromCIImage(_ image: CIImage) -> CVPixelBuffer? {
        let renderCropInsets = renderCropEdgeInsets
        
        if croppedRenderTarget == nil {
            let emptyAttributes: CFDictionary = [:] as CFDictionary
            let attributes: CFDictionary = [kCVPixelBufferIOSurfacePropertiesKey : emptyAttributes] as CFDictionary
            CVPixelBufferCreate(kCFAllocatorDefault, Int(renderSize.width),
                                Int(renderSize.height - renderCropInsets.top - renderCropInsets.bottom),
                                kCVPixelFormatType_32BGRA, attributes, &croppedRenderTarget)
        }
        
        guard let croppedRenderTarget = croppedRenderTarget else { return nil }
        
        let upsideTransform = CGAffineTransform.identity.translatedBy(x: 0, y: -renderCropInsets.top)
        let transformedImage = image.transformed(by: upsideTransform)
        CIContext().render(transformedImage, to: croppedRenderTarget)
        
        return croppedRenderTarget
    }
}
