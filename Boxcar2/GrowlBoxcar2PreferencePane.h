//
//  GrowlBoxcar2PreferencePane.h
//  Boxcar2
//
//  Created by Mickaël Rémond on 08/03/14.
//  Copyright (c) 2014 ProcessOne. All rights reserved.
//

#import <GrowlPlugins/GrowlPluginPreferencePane.h>

@interface GrowlBoxcar2PreferencePane : GrowlPluginPreferencePane <NSURLConnectionDelegate>

@property (nonatomic, retain) NSString *errorMessage;
@property (nonatomic) BOOL validating;

-(NSString*)accessToken;
-(void)setAccessToken:(NSString*)newToken;

-(NSString*)prefixString;
-(void)setPrefixString:(NSString *)newPrefix;

-(BOOL)usePrefix;
-(void)setUsePrefix:(BOOL)prefix;

-(BOOL)pushIdle;
-(void)setPushIdle:(BOOL)push;

-(BOOL)usePriority;
-(void)setUsePriority:(BOOL)use;

-(int)minPriority;
-(void)setMinPriority:(int)min;

@end
