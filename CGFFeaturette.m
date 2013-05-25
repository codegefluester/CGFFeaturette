//
//  CGFFeaturette.m
//  CGFFeaturette
//
//  Created by Björn Kaiser on 25.05.13.
//  Copyright (c) 2013 Björn Kaiser. All rights reserved.
//

#import "CGFFeaturette.h"

#include <sys/types.h>
#include <sys/sysctl.h>

@interface CGFFeaturette ()

@property (strong, nonatomic) NSString *baseUrl;
@property (strong, nonatomic) NSURL *featureFilelUrl;
@property (strong) NSOperationQueue *queue;
@property (strong) NSDictionary *config;
@property (strong) NSArray *features;
@property (strong) NSMutableDictionary *featureCache;

@property (strong) NSString *deviceFamily; // tablet (iPad), phone (iPhone/iPod Touch)
@property (strong) NSString *deviceVersion; // e.g. iPhone 4 / iPad Mini
@property (strong) NSString *deviceOSVersion;

- (void) loadFeatureFile;
- (void) createFeatureCache;

- (NSString *) platformString;
- (NSString *) platform;
- (void) collectDeviceInfo;

@end

@implementation CGFFeaturette

@synthesize defaultsToEnabled = _defaultsToEnabled;

static CGFFeaturette *_sharedInstance = nil;

+ (CGFFeaturette*) startWithBaseUrl:(NSString*)theUrl
{
    
    if (_sharedInstance == nil) {
        _sharedInstance = [[CGFFeaturette alloc] init];
        _sharedInstance.baseUrl = theUrl;
        _sharedInstance.featureFilelUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", theUrl, FEATURE_FILE]];
        _sharedInstance.queue = [NSOperationQueue new];
        _sharedInstance.featureCache = [[NSMutableDictionary alloc] init];
        
        if (_sharedInstance.featureFilelUrl != nil) {
            CGFFLog(@"Started with URL %@", _sharedInstance.featureFilelUrl);
            // Load the feature file
            [_sharedInstance collectDeviceInfo];
            [_sharedInstance loadFeatureFile];
        }
    }
    
    return _sharedInstance;
}

- (void) collectDeviceInfo
{
    self.deviceFamily = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad ? @"tablet" : @"phone";
    self.deviceVersion = [self platform];
    self.deviceOSVersion = [[UIDevice currentDevice] systemVersion];
    
    NSLog(@"%@", self.deviceFamily);
}

- (void) reloadFeatures
{
    NSLog(@"Reloading features...");
    [self loadFeatureFile];
}

- (void) loadFeatureFile
{
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:_featureFilelUrl] queue:self.queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (!error) {
            NSError *jsonError;
            self.config = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonError];
            if (!jsonError) {
                // Remove all cached features
                [self.featureCache removeAllObjects];
                
                self.features = [self.config objectForKey:@"features"];
                [self createFeatureCache];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:kCGFFeaturetteDidLoadFeaturesNotifiaction object:nil];
            } else {
                // Failed to parse JSON
                CGFFLog(@"Loaded features.json is not valid JSON");
                [[NSNotificationCenter defaultCenter] postNotificationName:kCGFFeaturetteDidFailNotifiaction object:nil];
            }
        } else {
            // Failed to load feature file, notify observers, they should decide what to do
            CGFFLog(@"Failed to load features with error %@", error.description);
            [[NSNotificationCenter defaultCenter] postNotificationName:kCGFFeaturetteDidFailNotifiaction object:nil];
        }
    }];
}

- (void) createFeatureCache
{
    
    // Generate the cache for all features
    if (self.features.count > 0) {
        for (NSDictionary *ft in self.features) {
            NSString *key = [ft objectForKey:@"key"];
            NSUInteger featureIndex = [self.features indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                return [[obj objectForKey:@"key"] isEqualToString:key] ? YES : NO;
            }];
            
            if (featureIndex < self.features.count) {
                NSDictionary *feature = [self.features objectAtIndex:featureIndex];
                
                BOOL featureEnabled = [[feature objectForKey:@"enabled"] boolValue];
                
                // The feature is enabled, check if there are device/os restrictions
                if(featureEnabled) {
                    NSArray *osFilter = [feature objectForKey:@"only-os"];
                    if(osFilter != nil && osFilter.count > 0) {
                        BOOL __block osAllowed = NO;
                        [osFilter enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                            if([self.deviceOSVersion hasPrefix:obj]) osAllowed = YES;
                        }];
                        
                        if(!osAllowed) featureEnabled = NO;
                    }
                    
                    NSArray *deviceFilter = [feature objectForKey:@"only-device"];
                    if(deviceFilter != nil && featureEnabled) {
                        BOOL __block deviceAllowed = NO;
                        // Check if the device we're running on is supported
                        [deviceFilter enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                            if([self.deviceVersion hasPrefix:obj]) deviceAllowed = YES;
                        }];
                        
                        if(!deviceAllowed) featureEnabled = NO;
                    }
                    
                    NSArray *deviceFamilyFilter = [feature objectForKey:@"only-device-family"];
                    if(deviceFamilyFilter != nil && featureEnabled) {
                        BOOL __block deviceFamilyAllowed = NO;
                        // Check if the device we're running on is supported
                        [deviceFamilyFilter enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                            if([self.deviceFamily isEqualToString:obj]) deviceFamilyAllowed = YES;
                        }];
                        
                        if(!deviceFamilyAllowed) featureEnabled = NO;
                    }
                }
                
                // Cache the result
                [self.featureCache setObject:[NSNumber numberWithBool:featureEnabled] forKey:key];
            }
        }
        
        NSLog(@"Feature cache created %@", self.featureCache);
    }
}

- (void) setDefaultsToEnabled:(BOOL)yn
{
    _defaultsToEnabled = yn;
}

- (BOOL) defaultsToEnabled
{
    return _defaultsToEnabled;
}

- (BOOL) featureEnabled:(NSString *)key
{
    // Check if we have a cached result
    if ([self.featureCache objectForKey:key] != nil) {
        return [[self.featureCache objectForKey:key] boolValue];
    }
    
    CGFFLog(@"Feature %@ could not be found", key);
    return self.defaultsToEnabled ? YES : NO;
}

#pragma mark -
#pragma mark Internals

/**
 *  Determine the exact hardware we're running on
 *  http://stackoverflow.com/questions/448162/determine-device-iphone-ipod-touch-with-iphone-sdk/1561920#1561920
 **/
- (NSString *) platform
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithUTF8String:machine];
    free(machine);
    return platform;
}

- (NSString *) platformString
{
    NSString *platform = [self platform];
    if ([platform isEqualToString:@"iPhone1,1"])    return @"iPhone 1G";
    if ([platform isEqualToString:@"iPhone1,2"])    return @"iPhone 3G";
    if ([platform isEqualToString:@"iPhone2,1"])    return @"iPhone 3GS";
    if ([platform isEqualToString:@"iPhone3,1"])    return @"iPhone 4";
    if ([platform isEqualToString:@"iPhone3,3"])    return @"Verizon iPhone 4";
    if ([platform isEqualToString:@"iPhone4,1"])    return @"iPhone 4S";
    if ([platform isEqualToString:@"iPhone5,1"])    return @"iPhone 5 (GSM)";
    if ([platform isEqualToString:@"iPhone5,2"])    return @"iPhone 5 (GSM+CDMA)";
    if ([platform isEqualToString:@"iPod1,1"])      return @"iPod Touch 1G";
    if ([platform isEqualToString:@"iPod2,1"])      return @"iPod Touch 2G";
    if ([platform isEqualToString:@"iPod3,1"])      return @"iPod Touch 3G";
    if ([platform isEqualToString:@"iPod4,1"])      return @"iPod Touch 4G";
    if ([platform isEqualToString:@"iPod5,1"])      return @"iPod Touch 5G";
    if ([platform isEqualToString:@"iPad1,1"])      return @"iPad";
    if ([platform isEqualToString:@"iPad2,1"])      return @"iPad 2 (WiFi)";
    if ([platform isEqualToString:@"iPad2,2"])      return @"iPad 2 (GSM)";
    if ([platform isEqualToString:@"iPad2,3"])      return @"iPad 2 (CDMA)";
    if ([platform isEqualToString:@"iPad2,4"])      return @"iPad 2 (WiFi)";
    if ([platform isEqualToString:@"iPad2,5"])      return @"iPad Mini (WiFi)";
    if ([platform isEqualToString:@"iPad2,6"])      return @"iPad Mini (GSM)";
    if ([platform isEqualToString:@"iPad2,7"])      return @"iPad Mini (GSM+CDMA)";
    if ([platform isEqualToString:@"iPad3,1"])      return @"iPad 3 (WiFi)";
    if ([platform isEqualToString:@"iPad3,2"])      return @"iPad 3 (GSM+CDMA)";
    if ([platform isEqualToString:@"iPad3,3"])      return @"iPad 3 (GSM)";
    if ([platform isEqualToString:@"iPad3,4"])      return @"iPad 4 (WiFi)";
    if ([platform isEqualToString:@"iPad3,5"])      return @"iPad 4 (GSM)";
    if ([platform isEqualToString:@"iPad3,6"])      return @"iPad 4 (GSM+CDMA)";
    if ([platform isEqualToString:@"i386"])         return @"Simulator";
    if ([platform isEqualToString:@"x86_64"])       return @"Simulator";
    return platform;
}

@end
