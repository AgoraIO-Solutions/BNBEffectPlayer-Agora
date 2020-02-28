#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <GLKit/GLKit.h>

@interface OutputSettings : NSObject

@property(nonatomic) UIDeviceOrientation deviceOrientation;
@property(nonatomic) BOOL isMirrored;
@property(nonatomic) BOOL applyWatermark;

@property(nonatomic, readonly) BOOL shouldApplyVerticalFlip;
@property(nonatomic, readonly) BOOL shouldApplyHorizontalFlip;
@property(nonatomic, readonly) CGAffineTransform resultVideoTransform;
@property(nonatomic, readonly) UIImageOrientation resultImageOrientation;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithOrientation:(UIDeviceOrientation)orientation isMirrored:(BOOL)isMirrored
                     applyWatermark:(BOOL)applyWatermark NS_DESIGNATED_INITIALIZER;

@end

@interface SBVideoWriter : NSObject

- (instancetype)initWithSize:(CGSize)size outputSettings:(OutputSettings*)settings;

- (void)pushAudioSampleBuffer:(CMSampleBufferRef)buffer;
- (void)pushVideoSampleBuffer:(CVPixelBufferRef)buffer;

- (void)prepareInputs:(NSURL*)fileUrl;
- (void)startCapturingScreenWithUrl:(NSURL*)fileUrl completion:(void (^)(BOOL, NSError*))completionHandler;
- (void)startCapturingScreen:(void (^)(BOOL, NSError*))completionHandler;
- (void)stopCapturing;
- (void)discardCapturing;
+ (BOOL)isEnoughDiskSpaceForRecording;

@end
