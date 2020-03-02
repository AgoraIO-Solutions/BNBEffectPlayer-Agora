#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef NS_ENUM(NSUInteger, EPOrientation) {
    EPOrientationAngles0,
    EPOrientationAngles90,
    EPOrientationAngles180,
    EPOrientationAngles270

};


typedef struct
{
    CGSize cameraSize;
    CGSize screenSize;
    EPOrientation orientation;
    BOOL isMirrored;
    NSUInteger fov;
    BOOL isYFlip; // if false, (0,0) in bottom left, else in top left
} EpImageFormat;

/**
 * Все методы должны вызываться из одного и того же потока
 * (в котором был создан объектBNBOffscreenEffectPlayer)
 * Все методы синхронные

 */
@interface BNBOffscreenEffectPlayer : NSObject

/*
 * в directories можно передать пути где можно найти эффект, если путь к эффектам задается относительно
 * effectWidth andHeight размер внутреней области, в которую рисуется эфект
 */
- (instancetype _Nonnull)initWithDirectories:(NSArray<NSString*>* _Nullable)directories
                                 effectWidth:(NSUInteger)width
                                   andHeight:(NSUInteger)height;

/*
* EpImageFormat::cameraSize - размер входной RGBA картинки
* EpImageFormat::screenSize не используется
* размер выходной картинки равен размеру внутреней области, в которую рисуется эффект
*/
- (NSData* _Nonnull)processImage:(NSData* _Nonnull)inputRgba
                      withFormat:(EpImageFormat* _Nonnull)imageFormat;

- (void)loadEffect:(NSString* _Nonnull)effectName;
- (void)unloadEffect;

/*
 *pause/resume управляет только проигрыванием аудио
 */
- (void)pause;
- (void)resume;

@end
