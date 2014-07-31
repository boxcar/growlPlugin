//
//  GrowlBoxcar2Action.h
//  Boxcar2
//
//  Created by Mickaël Rémond on 08/03/14.
//  Copyright (c) 2014 ProcessOne. All rights reserved.
//

#import <GrowlPlugins/GrowlActionPlugin.h>

@interface GrowlBoxcar2Action : GrowlActionPlugin <GrowlDispatchNotificationProtocol, GrowlUpgradePluginPrefsProtocol, NSURLConnectionDelegate>

@end
