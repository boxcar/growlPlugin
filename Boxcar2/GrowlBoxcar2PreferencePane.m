//
//  GrowlBoxcar2PreferencePane.m
//  Boxcar2
//
//  Created by Mickaël Rémond on 08/03/14.
//  Copyright (c) 2014 ProcessOne. All rights reserved.
//
//  This class represents your plugin's preference pane.  There will be only one instance, but possibly many configurations
//  In order to access a configuration values, use the NSMutableDictionary *configuration for getting them. 
//  In order to change configuration values, use [self setConfigurationValue:forKey:]
//  This ensures that the configuration gets saved into the database properly.

#import "GrowlBoxcar2PreferencePane.h"
#import "BoxcarDefines.h"

@interface GrowlBoxcar2PreferencePane ()

@property(nonatomic, retain) NSMutableArray *connections;
@property(nonatomic, retain) NSString *testToken;

@property(nonatomic, retain) NSString *tokenLabel;
@property(nonatomic, retain) NSString *onlyIfPriorityLabel;
@property(nonatomic, retain) NSString *onlyIfIdleLabel;
@property(nonatomic, retain) NSString *prefixLabel;

@end

@implementation GrowlBoxcar2PreferencePane

@synthesize errorMessage;
@synthesize validating;

@synthesize connections;
@synthesize testToken;

@synthesize tokenLabel;
@synthesize onlyIfPriorityLabel;
@synthesize onlyIfIdleLabel;
@synthesize prefixLabel;

- (id)initWithBundle:(NSBundle *)bundle {
    if ((self = [super initWithBundle:bundle])) {
        self.validating = NO;
        self.connections = [NSMutableArray array];

        self.tokenLabel = NSLocalizedStringFromTableInBundle(@"Boxcar 2 Access Token:", @"Localizable", bundle, @"Boxcar 2 access token field label");
        self.onlyIfPriorityLabel = NSLocalizedStringFromTableInBundle(@"Only send if priority is at least:", @"Localizable", bundle, @"Checkbox for sending only if priority is above a certain value");
        self.onlyIfIdleLabel = NSLocalizedStringFromTableInBundle(@"Only send if idle:", @"Localizable", bundle, @"Checkbox for only sending if idle by growl's idle detection");
        self.prefixLabel = NSLocalizedStringFromTableInBundle(@"Prefix notifications with:", @"Localizable", bundle, @"Prefix notifications to boxcar checkbox");
    }
    return self;
}

- (NSString *)mainNibName {
    return @"Boxcar2PrefPane";
}

/* This returns the set of keys the preference pane needs updated via bindings
 * This is called by GrowlPluginPreferencePane when it has had its configuration swapped
 * Since we really only need a fixed set of keys updated, use dispatch_once to create the set
 */
- (NSSet *)bindingKeys {
    static NSSet *keys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = [NSSet setWithObjects:@"accessToken",
                                     @"prefixString",
                                     @"usePrefix",
                                     @"usePriority",
                                     @"minPriority",
                                     @"pushIdle", nil];
    });
    return keys;
}

/* This method is called when our configuration values have been changed
 * by switching to a new configuration.  This is where we would update certain things
 * that are unbindable.  Call the super version in order to ensure bindingKeys is also called and used.
 * Uncomment the method to use.
 */
- (void)updateConfigurationValues {
    [super updateConfigurationValues];
    [self checkAccessToken:[self accessToken]];
}

- (void)checkAccessToken:(NSString *)accessToken {
    if (!accessToken || [accessToken isEqualToString:@""]) {
        return;
    }
    self.testToken = accessToken;

    [self setConfigurationValue:accessToken forKey:BoxcarToken];
    NSURL *baseURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://new.boxcar.io/api/check_user_token/%@", accessToken]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:baseURL];
    [request setHTTPMethod:@"GET"];

    self.errorMessage = @"";
    self.validating = YES;

    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request
                                                                  delegate:self
                                                          startImmediately:NO];
    [connections addObject:connection];
    [connection setDelegateQueue:[NSOperationQueue mainQueue]];
    [connection start];
}

- (NSString *)accessToken {
    return [self.configuration valueForKey:BoxcarToken];
}

- (void)setAccessToken:(NSString *)newToken {
    [self checkAccessToken:newToken];
    [self setConfigurationValue:newToken forKey:BoxcarToken];
}

- (NSString *)prefixString {
    return [self.configuration valueForKey:BoxcarPrefixString];
}

- (void)setPrefixString:(NSString *)newPrefix {
    [self setConfigurationValue:newPrefix forKey:BoxcarPrefixString];
}

- (BOOL)usePrefix {
    BOOL value = BoxcarUsePrefixDefault;
    if ([self.configuration valueForKey:BoxcarUsePrefix]) {
        value = [[self.configuration valueForKey:BoxcarUsePrefix] boolValue];
    }
    return value;
}

- (void)setUsePrefix:(BOOL)prefix {
    [self setConfigurationValue:[NSNumber numberWithBool:prefix] forKey:BoxcarUsePrefix];
}

- (BOOL)pushIdle {
    BOOL value = BoxcarUseIdleDefault;
    if ([self.configuration valueForKey:BoxcarPushIdle]) {
        value = [[self.configuration valueForKey:BoxcarPushIdle] boolValue];
    }
    return value;
}

- (void)setPushIdle:(BOOL)push {
    [self setConfigurationValue:[NSNumber numberWithBool:push] forKey:BoxcarPushIdle];
}

- (BOOL)usePriority {
    BOOL value = BoxcarUsePriorityDefault;
    if ([self.configuration valueForKey:BoxcarUsePriority]) {
        value = [[self.configuration valueForKey:BoxcarUsePriority] boolValue];
    }
    return value;
}

- (void)setUsePriority:(BOOL)use {
    [self setConfigurationValue:[NSNumber numberWithBool:use] forKey:BoxcarUsePriority];
}

- (int)minPriority {
    int value = BoxcarMinPriorityDefault;
    if ([self.configuration valueForKey:BoxcarMinPriority]) {
        value = [[self.configuration valueForKey:BoxcarMinPriority] intValue];
    }
    return value;
}

- (void)setMinPriority:(int)min {
    [self setConfigurationValue:[NSNumber numberWithInt:min] forKey:BoxcarMinPriority];
}

#pragma mark NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    if ([response respondsToSelector:@selector(statusCode)]) {
        NSInteger status = [(NSHTTPURLResponse *) response statusCode];
        switch (status) {
            case 200:
                //SUCCESS!
                self.errorMessage = NSLocalizedString(@"Valid token!", @"Success adding Boxcar");
                NSLog(@"Access token is valid");
                [self setConfigurationValue:self.testToken forKey:BoxcarToken];
                break;
            case 401:
                self.errorMessage = NSLocalizedString(@"Invalid token", @"Access token is invalid");
                NSLog(@"Access token is invalid");
                [self willChangeValueForKey:@"accessToken"];
                [self setConfigurationValue:nil forKey:BoxcarToken];
                [self didChangeValueForKey:@"accessToken"];
                break;
            case 404:
                // No devices registered
                self.errorMessage = NSLocalizedString(@"Valid token, no device", @"Success adding Boxcar but no device for user");
                NSLog(@"Success adding Boxcar but no device for user");
                break;
            default:
                //Unknown response
                self.errorMessage = [NSString stringWithFormat:@"Error %lu", status];
                NSLog(@"Unknown response code from boxcar: %lu", status);
                break;
        }
    } else {
        NSLog(@"Error! Should be able to get a status code");
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"connection %@ failed with error %@", connection, error);
    [self willChangeValueForKey:@"accessToken"];
    [self setConfigurationValue:nil forKey:BoxcarToken];
    [self didChangeValueForKey:@"accessToken"];
    [connections removeObject:connection];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    self.validating = NO;
    self.testToken = nil;
    [connections removeObject:connection];
}

@end
