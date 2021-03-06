// AUTOGENERATED FILE - DO NOT MODIFY!
// This file generated by Djinni from scene.djinni

#import "BNBAnimationMode.h"
#import <Foundation/Foundation.h>
@class BNBMaterial;
@class BNBMesh;
@class BNBParameter;


@interface BNBMeshInstance : NSObject

- (void)setVisible:(BOOL)visible;

- (BOOL)isVisible;

- (void)setMaterial:(nullable BNBMaterial *)material;

- (nullable BNBMaterial *)getMaterial;

- (void)setMesh:(nullable BNBMesh *)mesh
  geometryIndex:(int32_t)geometryIndex;

- (nullable BNBMesh *)getMesh;

- (int32_t)getGeometryIndex;

- (void)animationChange:(nonnull NSString *)animation
                   mode:(BNBAnimationMode)mode;

- (void)animationPlay;

- (void)animationPause;

- (void)animationSeek:(int64_t)positionNs;

- (BOOL)isAnimationPlaying;

- (nonnull NSString *)getAnimation;

- (BNBAnimationMode)getAnimationMode;

- (int64_t)getAnimationPositionNs;

- (int64_t)getAnimationDurationNs;

- (int64_t)getAnimationTimeOffsetNs;

- (void)setAnimationTimeOffsetNs:(int64_t)timeNs;

- (void)addParameter:(nullable BNBParameter *)parameter;

- (nonnull NSArray<BNBParameter *> *)getParameters;

- (void)removeParameter:(nullable BNBParameter *)parameter;

@end
