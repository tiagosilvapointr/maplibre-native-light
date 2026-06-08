#import "LightViewController.h"

@implementation LightViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = [UIColor whiteColor];

  // Load the bundled plugin-style.json so we can repro tile-loading issues
  // against the light SDK in isolation.
  NSURL *styleURL = [[NSBundle mainBundle] URLForResource:@"plugin-style"
                                            withExtension:@"json"];
  if (!styleURL) {
    NSLog(@"[AppLight] plugin-style.json not found in bundle, falling back to "
          @"demotiles");
    styleURL = [NSURL URLWithString:@"https://demotiles.maplibre.org/style.json"];
  }
  NSLog(@"[AppLight] Loading style: %@", styleURL);

  self.mapView = [[MLNMapView alloc] initWithFrame:self.view.bounds
                                          styleURL:styleURL];
  self.mapView.autoresizingMask =
      UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  self.mapView.delegate = self;
  [self.view addSubview:self.mapView];
}

#pragma mark - MLNMapViewDelegate

- (void)mapView:(MLNMapView *)mapView didFinishLoadingStyle:(MLNStyle *)style {
  NSLog(@"[AppLight] didFinishLoadingStyle — %lu sources, %lu layers",
        (unsigned long)style.sources.count, (unsigned long)style.layers.count);
}

- (void)mapViewDidFinishLoadingMap:(MLNMapView *)mapView {
  NSLog(@"[AppLight] mapViewDidFinishLoadingMap");
}

- (void)mapViewDidFailLoadingMap:(MLNMapView *)mapView
                       withError:(NSError *)error {
  NSLog(@"[AppLight] mapViewDidFailLoadingMap: %@", error);
}

- (nullable UIImage *)mapView:(MLNMapView *)mapView
           didFailToLoadImage:(NSString *)imageName {
  NSLog(@"[AppLight] didFailToLoadImage: %@", imageName);
  return nil;
}

@end
