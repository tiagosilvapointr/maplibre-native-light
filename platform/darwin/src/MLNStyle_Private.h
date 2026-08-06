#import "MLNStyle.h"

#if !defined(MBGL_LAYER_FILL_DISABLE_ALL)
#import "MLNFillStyleLayer.h"
#endif
#import "MLNStyleLayer.h"

NS_ASSUME_NONNULL_BEGIN

namespace mbgl {
namespace style {
class Style;
}
}  // namespace mbgl

@class MLNAttributionInfo;
@class MLNMapView;
#if !defined(MBGL_LAYER_CUSTOM_DISABLE_ALL)
@class MLNCustomStyleLayer;
#endif
@class MLNVectorTileSource;
@class MLNVectorStyleLayer;

@interface MLNStyle (Private)

- (instancetype)initWithRawStyle:(mbgl::style::Style *)rawStyle stylable:(id<MLNStylable>)stylable;

@property (nonatomic, readonly, weak) id<MLNStylable> stylable;
@property (nonatomic, readonly) mbgl::style::Style *rawStyle;

- (nullable NSArray<MLNAttributionInfo *> *)attributionInfosWithFontSize:(CGFloat)fontSize
                                                               linkColor:
                                                                   (nullable MLNColor *)linkColor;
#if !defined(MBGL_LAYER_CUSTOM_DISABLE_ALL)
@property (nonatomic, readonly, strong)
    NSMutableDictionary<NSString *, MLNCustomStyleLayer *> *customLayers;
#endif
- (void)setStyleClasses:(NSArray<NSString *> *)appliedClasses
     transitionDuration:(NSTimeInterval)transitionDuration;

@end

@interface MLNStyle (MLNStreetsAdditions)

@property (nonatomic, readonly, copy) NSArray<MLNVectorStyleLayer *> *placeStyleLayers;
@property (nonatomic, readonly, copy) NSArray<MLNVectorStyleLayer *> *roadStyleLayers;

@end

NS_ASSUME_NONNULL_END
