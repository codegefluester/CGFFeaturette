//
//  CGFFeaturette.h
//  CGFFeaturette
//
//  Created by Björn Kaiser on 25.05.13.
//  Copyright (c) 2013 Björn Kaiser. All rights reserved.
//

#import <Foundation/Foundation.h>


#define CGFFLog(f, ...) NSLog(@"CGFFeaturette: %@", [NSString stringWithFormat:(f), ##__VA_ARGS__])
#define FEATURE_FILE @"features.json"
#define kCGFFeaturetteDidLoadFeaturesNotification @"CGFFeaturetteDidLoadFeaturesNotifiaction"
#define kCGFFeaturetteDidFailNotification @"CGFFeaturetteDidFailNotifiaction"

@interface CGFFeaturette : NSObject


@property BOOL defaultsToEnabled;

+ (CGFFeaturette*) startWithBaseUrl:(NSString*)theUrl;
- (void) setDefaultsToEnabled:(BOOL)yn;
- (BOOL) featureEnabled:(NSString*)key;
- (void) reloadFeatures;

@end
