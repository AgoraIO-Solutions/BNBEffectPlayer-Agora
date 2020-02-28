// AUTOGENERATED FILE - DO NOT MODIFY!
// This file generated by Djinni from scene.djinni

#import "BNBTextureFilteringMode.h"
#import <Foundation/Foundation.h>


@interface BNBTexture : NSObject

/** Load texture from specified file */
- (void)load:(nonnull NSString *)fileName;

/** Get width of loaded image */
- (int32_t)getWidth;

/** Get height of loaded image */
- (int32_t)getHeight;

/** Get number of images in mipmap chain */
- (int32_t)getLevels;

- (int32_t)getLayers;

/** Enable/disable mipmaps generation (on by default) */
- (void)setMips:(BOOL)enable;

/** Get current mipmaps generation setting */
- (BOOL)hasMips;

/** Enable/disable texture tiling */
- (void)setTiling:(BOOL)enable;

/** Get current tiling setting */
- (BOOL)getTiling;

/** Set texture filtering mode (linear by default) */
- (void)setFiltering:(BNBTextureFilteringMode)type;

/** Get current filtering mode */
- (BNBTextureFilteringMode)getFilteringMode;

/** Set vertical flip on load */
- (void)setVflip:(BOOL)enable;

/** Get vertical flip setting */
- (BOOL)isVflipped;

@end
