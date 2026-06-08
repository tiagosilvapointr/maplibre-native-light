#import <UIKit/UIKit.h>

#import "MLNMapView.h"
#import "MLNMapViewDelegate.h"
#import "MLNStyle.h"

@interface LightViewController : UIViewController <MLNMapViewDelegate>

@property (strong, nonatomic) MLNMapView *mapView;

@end
