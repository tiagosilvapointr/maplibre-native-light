#import "LightAppDelegate.h"
#import "LightViewController.h"

@implementation LightAppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  self.window.rootViewController = [[LightViewController alloc] init];
  [self.window makeKeyAndVisible];
  return YES;
}

@end
