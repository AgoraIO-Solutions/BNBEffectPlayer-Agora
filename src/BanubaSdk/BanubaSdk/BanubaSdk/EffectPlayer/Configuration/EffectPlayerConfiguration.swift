//
//  EffectPlayerConfinguration.swift
//  Easy Snap
//
//  Created by Victor Privalov on 7/16/18.
//  Copyright © 2018 Banuba. All rights reserved.
//

import BanubaEffectPlayer

public enum EffectPlayerRenderMode {
    case photo
    case video
}

public struct EffectPlayerConfinguration {
    public struct Defaults {
        public static let photoRenderSize: CGSize = CGSize(width: 960, height: 1280) // 3x4 default photo aspect ratio
        public static let videoRenderSize: CGSize = CGSize(width: 720, height: 1280) // 9x16 default video aspect ratio
        
        public static let defaultFramerate: Int = 60
    }
    
    public let cameraMode: CameraSessionType
    public var renderSize: CGSize
    
    // Size of final surface, from which render is blitted onto layer in client side,
    // is calculated using this params - layer size multiplied with this scale.
    // Due to some internal implementation details, recorded video would have resolution equal to size of this surface.
    // By default, this scale has value of main screen' scale. For slower devices (iPads, 5S) it could be set as 1.
    public var surfaceScale: CGFloat

    public var preferredRenderFramerate: Int
    public var shouldAutoStartOnEnterForeground: Bool
    public var fov: Float
    public var isMirrored: Bool
    public var flipVertically: Bool
    public var orientation: BNBCameraOrientation
    public var notificationCenter: NotificationCenter
    
    public init(renderMode: EffectPlayerRenderMode,
                surfaceScale: CGFloat = UIScreen.main.scale,
                orientation: BNBCameraOrientation = .deg0,
                preferredRenderFramerate: Int = EffectPlayerConfinguration.Defaults.defaultFramerate,
                shouldAutoStartOnEnterForeground: Bool = true,
                isMirrored: Bool = false,
                fov : Float = 0.0,
                notificationCenter: NotificationCenter = NotificationCenter.default) {
        let renderSize = (renderMode == .video) ? Defaults.videoRenderSize : Defaults.photoRenderSize
        let cameraMode: CameraSessionType = (renderMode == .video) ? .FrontCameraVideoSession : .FrontCameraPhotoSession
        
        self.init(cameraMode: cameraMode, renderSize: renderSize, surfaceScale: surfaceScale, orientation: orientation,
                  preferredRenderFramerate: preferredRenderFramerate, shouldAutoStartOnEnterForeground: shouldAutoStartOnEnterForeground,
                  isMirrored: isMirrored, flipVertically: false, fov: fov, notificationCenter: notificationCenter)
    }
    
    public init(cameraMode: CameraSessionType,
                renderSize: CGSize,
                surfaceScale: CGFloat = UIScreen.main.scale,
                orientation: BNBCameraOrientation = .deg0,
                preferredRenderFramerate: Int = EffectPlayerConfinguration.Defaults.defaultFramerate,
                shouldAutoStartOnEnterForeground: Bool = true,
                isMirrored: Bool = false,
                flipVertically: Bool = true,
                fov : Float = 0.0,
                notificationCenter: NotificationCenter = NotificationCenter.default) {
        self.cameraMode = cameraMode
        self.surfaceScale = surfaceScale

        // Render size - specifies in which resolution effect player will render input data, and provide it back for further usage.
        // As described below, input size and render size should have same aspect ratio.
        // Also, surfaceCreated method should use the same value (renderSize) for width and height, to correctly display render on layer.
        // Layer itself could have any size, render will be scaled properly (Of course, layer should have same aspect ratio to prevent scaling distortions).
        self.renderSize = renderSize

        // Render loop triggers draw method with 60 fps by default, but in editing mode, when we render the same frame,
        // it's not needed, so we can make it lower with this parameter.
        self.preferredRenderFramerate = preferredRenderFramerate
        
        self.shouldAutoStartOnEnterForeground = shouldAutoStartOnEnterForeground
        self.orientation = orientation
        self.isMirrored = isMirrored
        self.flipVertically = flipVertically
        self.fov = fov
        self.notificationCenter = notificationCenter
    }
}

