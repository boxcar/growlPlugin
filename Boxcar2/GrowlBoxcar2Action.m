//
//  GrowlBoxcar2Action.m
//  Boxcar2
//
//  Created by Mickaël Rémond on 08/03/14.
//  Copyright (c) 2014 ProcessOne. All rights reserved.
//
//  This class is where the main logic of dispatching a notification via your plugin goes.
//  There will be only one instance of this class, so use the configuration dictionary for figuring out settings.
//  Be aware that action plugins will be dispatched on the default priority background concurrent queue.
//  

#import "GrowlBoxcar2Action.h"
#import "GrowlBoxcar2PreferencePane.h"
#import "BoxcarDefines.h"
#import <GrowlPlugins/GrowlDefines.h>
#import <GrowlPlugins/GrowlIdleStatusObserver.h>
#import <GrowlPlugins/GrowlKeychainUtilities.h>
#import <GrowlPlugins/NSURL+StringEncoding.h>

@interface GrowlBoxcar2Action ()

@property(nonatomic, retain) NSMutableArray *connections;

@end

@implementation GrowlBoxcar2Action

@synthesize connections;

- (id)init {
    if ((self = [super init])) {
        self.prefDomain = BoxcarPrefDomain;
        self.connections = [NSMutableArray array];
    }
    return self;
}

- (NSDictionary *)upgradeConfigDict:(NSDictionary *)original toConfigID:(NSString *)configID {
    NSString *token = [original valueForKey:BoxcarToken];
    if (token && ![token isEqualToString:@""])
        [GrowlKeychainUtilities removePasswordForService:@"GrowlBoxcar2" accountName:token];
    return original;
}

/* Dispatch a notification with a configuration, called on the default priority background concurrent queue
 * Unless you need to use UI, do not send something to the main thread/queue.
 * If you have a requirement to be serialized, make a custom serial queue for your own use.
 */
- (void)dispatchNotification:(NSDictionary *)notification withConfiguration:(NSDictionary *)configuration {
    NSString *token = [configuration valueForKey:BoxcarToken];
    if (!token || [token isEqualToString:@""])
        return;

    NSString *event = [notification objectForKey:GROWL_NOTIFICATION_TITLE];
    NSString *application = [notification valueForKey:GROWL_APP_NAME];
    NSInteger priority = [[notification valueForKey:GROWL_NOTIFICATION_PRIORITY] intValue];
    BOOL isPreview = ([application isEqualToString:@"Growl"] && [event isEqualToString:@"Preview"]);

    if (!isPreview) {
        if ([configuration valueForKey:BoxcarPushIdle] &&
                [[configuration valueForKey:BoxcarPushIdle] boolValue] &&
                ![[GrowlIdleStatusObserver sharedObserver] isIdle]) {
            //NSLog(@"Not pushing because not idle");
            return;
        }

        if ([configuration valueForKey:BoxcarUsePriority] && [[configuration valueForKey:BoxcarUsePriority] boolValue]) {
            NSInteger minPriority = [configuration valueForKey:BoxcarMinPriority] ? [[configuration valueForKey:BoxcarMinPriority] integerValue] : BoxcarMinPriorityDefault;
            if (priority < minPriority) {
                //NSLog(@"Not pushing because priority too low");
                return;
            }
        }
    }

    NSURL *baseURL = [NSURL URLWithString:@"https://new.boxcar.io/api/notifications"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:baseURL
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                       timeoutInterval:100];

    NSString *title = [NSString stringWithFormat:@"%@", [notification objectForKey:GROWL_NOTIFICATION_TITLE]];
    NSString *prefix = [configuration valueForKey:BoxcarPrefixString];
    if ([configuration valueForKey:BoxcarUsePrefix] && [[configuration valueForKey:BoxcarUsePrefix] boolValue]) {
        if (prefix && ![prefix isEqualToString:@""])
            title = [NSString stringWithFormat:@"[%@] %@", prefix, title];
    }
    title = [NSURL encodedStringByAddingPercentEscapesToString:title];

    NSString *long_message = [NSString stringWithFormat:@"%@", [notification objectForKey:GROWL_NOTIFICATION_DESCRIPTION]];
    long_message = [NSURL encodedStringByAddingPercentEscapesToString:long_message];

    NSString *app = [NSURL encodedStringByAddingPercentEscapesToString:[notification valueForKey:GROWL_APP_NAME]];

    NSMutableString *dataString = [NSMutableString stringWithFormat:@"user_credentials=%@", token];
    [dataString appendFormat:@"&notification[subtitle]=%@", app];
    [dataString appendFormat:@"&notification[title]=%@", title];
    [dataString appendFormat:@"&notification[long_message]=%@", long_message];
    [dataString appendFormat:@"&notification[priority]=%ld", priority];
    // TODO: Support sound parameters
    [dataString appendFormat:@"&notification[sound]=%@", @"beep-soft"];
    NSData *data = [NSData dataWithBytes:[dataString UTF8String] length:[dataString lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:data];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"content-type"];

    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request
                                                                  delegate:self
                                                          startImmediately:NO];
    [connections addObject:connection];
    [connection setDelegateQueue:[NSOperationQueue mainQueue]];
    [connection start];
}

#pragma mark NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    if ([response respondsToSelector:@selector(statusCode)]) {
        NSInteger status = [(NSHTTPURLResponse *) response statusCode];
        switch (status) {
            case 201:
                //SUCCESS!
                NSLog(@"Success notifiying");
                break;
            case 401:
                // invalid token
                NSLog(@"This access token is invalid");
                break;
            case 404:
                // No devices
                NSLog(@"This account has no device");
                break;
            default:
                //Unknown response
                NSLog(@"Action: Unknown response code from boxcar: %lu", status);
                break;
        }
    } else {
        NSLog(@"Error! Should be able to get a status code");
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"connection %@ failed with error %@", connection, error);
    [connections removeObject:connection];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [connections removeObject:connection];
}

#pragma mark -

/* Auto generated method returning our PreferencePane, do not touch */
- (GrowlPluginPreferencePane *)preferencePane {
    if (!preferencePane)
        preferencePane = [[GrowlBoxcar2PreferencePane alloc] initWithBundle:[NSBundle bundleForClass:[self class]]];

    return preferencePane;
}

@end
