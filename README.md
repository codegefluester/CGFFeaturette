## CGFFeaturette
A remote killswitch for App features.

## What is this dude?
When I attended Facebook Mobile DevCon 2013 in London, Facebook gave us a little insight on how they build their iOS Apps (Facebook, Messenger etc.).

Facebook has the philosophy that each feature in their Apps should have have a On/Off switch to remotely activate and deactivate them in case they cause trouble or haven't been launched yet.

In case you could not attend the conference, the presentation slides and almost all session videos are available on the [event website](https://developers.facebook.com/events/mobiledevcon/london/).

I was looking for something similar for our App for a long time but didn't find any ready to run library that would help me implement just that. So **CGFFeaturette** was born.

## What can it do?
**CGFFeaturette** uses a simple JSON file that you put on your webserver of choice to check if a certain App feature is available.

#### You can enable features for…

- ...all devices/iOS versions  
- ...specified iOS versions
- ...specified devices
- …specified device families (e.g. only for tablets) 
- …combinations of everything mentioned above

## Configuration examples

#### Enable a feature for all devices/families/iOS versions
```
{
	"version" : "1.0",
	"features" : [
		{
			"key" : "facebook-login",
			"enabled" : true
		}
	]
}
```

#### Enable a feature only for iOS 6
```
{
	"version" : "1.0",
	"features" : [
		{
			"key" : "facebook-login",
			"enabled" : true,
			"only-os-versions" : [
				"6"
			]
		}
	]
}
```

#### Enable a feature only for iPhone 5 and iPhone 4S running iOS 6
```
{
	"version" : "1.0",
	"features" : [
		{
			"key" : "facebook-login",
			"enabled" : true,
			"only-os-versions" : [
				"6"
			],
			"only-device" : [
				"iPhone5",
				"iPhone4,1"
			]
		}
	]
}
```

#### Disable a feature
```
{
	"version" : "1.0",
	"features" : [
		{
			"key" : "facebook-login",
			"enabled" : false
		}
	]
}
```

## Code examples
At first add the `CGFFeaturette.h` and `CGFFeaturette.m` to your project. There are no other dependencies.

**AppDelegate.h**

```
#import <UIKit/UIKit.h>
#import "CGFFeaturette.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

- (void) featuresDidLoad:(NSNotification*)notif;

@end
```

**AppDelegate.m**

```
@interface AppDelegate ()
@property (strong) CGFFeaturette *features;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // … usual window setup …
    
    // Subscribe to the kCGFFeaturetteDidLoadFeaturesNotification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(featuresDidLoad:) name:kCGFFeaturetteDidLoadFeaturesNotifiaction object:nil];
    
    // Set the base url for the feature file (np trailing slash pls.)
    self.features = [CGFFeaturette startWithBaseUrl:@"http://www.example.com"];
    
    // Want to auto-enable features that were not found in the config?
    [self.features setDefaultsToEnabled:NO];
    
    return YES;
}

- (void) featuresDidLoad:(NSNotification*)notif
{
    if([self.features featureEnabled:@"facebook-login"])
    {
        NSLog(@"Facebook enabled");
    } else {
        NSLog(@"Facebook is not enabled");
    }
}

@end
```

## ToDo
- Add more filters (e.g. min-os-version instead of defining each supported OS version individually)
- Tests
- Many more stuff