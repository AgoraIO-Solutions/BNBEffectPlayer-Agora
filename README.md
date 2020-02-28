# BNBEffectPlayer-Agora

This iOS app shows how the Banuba SDK can be integrated with the Agora SDK to have an augmented reality experience in a one-to-one video chat.

## Prerequisites

- Xcode 10.0+
- Physical iOS device (iPhone or iPad)

## Add the Agora Video SDK to the project

1. Download the [Agora Video SDK](https://www.agora.io/en/download/). Unzip the downloaded SDK package and copy the following file from the SDK `libs` folder into the sample application `BNBEffectPlayer-Agora/src/BanubaSDKApp/libs` folder:
    - `AgoraRtcEngineKit.framework`

## Build steps for iOS
----------------------
1. Open `src/BanubaSdk/BanubaSdk.xcworkspace` in XCode.
2. Run BanubaSdkApp target

## Notes:
------

* Agora application id is hardcoded in: `src/BanubaSdk/BanubaSdkApp/BanubaSdkApp/AppID.swift`. It belongs to Banuba's Agora account and intended only for testing purposes.
* Banuba temporary client token is placed in: `src/BanubaSdk/BanubaSdkApp/BanubaSdkApp/client_token`. It's should be used only during the testing period.
* The application is trying to connect to "demoroom" channel when the application starts, but you can change the channel in the UI.
* Vanilla Banuba and Agora SDKs are used for creating of the demo. Standard Banuba iOS Demo project was used as an Application template. It was modified according to "Basic-Video-Call" tutorial from Agora's samples (https://github.com/AgoraIO/Basic-Video-Call/tree/master/One-to-One-Video/Agora-iOS-Tutorial-Swift-1to1).
* We use BanubaSDKManager.outputService.startFrameForwarding for forward rendered CVPixelBuffer frames from the Banuba SDK.
* And we use "push mode" for providing CVPixelBuffer frames from Banuba SDK to Agora SDK (https://docs.agora.io/en/Video/custom_video_apple?platform=iOS)
