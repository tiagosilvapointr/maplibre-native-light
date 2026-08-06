#import "MLNMapOptions.h"

@interface MLNMapOptions ()

@end

@implementation MLNMapOptions

- (instancetype _Nonnull)init {
  self = [super init];
  if (self) {
    _styleURL = nil;
    _styleJSON = nil;
#if !defined(MBGL_LAYER_PLUGIN_DISABLE_ALL)
    _pluginLayers = nil;
#endif

    _actionJournalOptions = [[MLNActionJournalOptions alloc] init];
  }

  return self;
}

@end
