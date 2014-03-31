//
//  SYAppDelegate.m
//  SYScreenshotUploader
//
//  Created by Peter Stajger on 31/03/14.
//  Copyright (c) 2014 SynopsiTV. All rights reserved.
//

#import "SYAppDelegate.h"
#import <DropboxSDK/DropboxSDK.h>

//Step 1. Create your own Dropbox App at https://www.dropbox.com/developers/apps/create (you must
//be logged in). When prompt, use Dropbox API app -> Files and datastores -> YES (My app only needs access to files it creates).

//Step 2. Include file and set your dropbox app key and secret
#import "SYScreenshotUploader.h"
#define DROPBOX_APP_KEY @"w5jgn38x9gg9rk8"
#define DROPBOX_APP_SECRET @"7nxagslpeab935v"

//Step 3. Register your dropbox app to correct URL scheme (db-DROPBOX_APP_KEY) in Info.plist

@implementation SYAppDelegate



- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    //Step 4. Initialte shared uploader and set dropbox app key and secret
    [[SYScreenshotUploader sharedUploader] setDropboxAppKey:DROPBOX_APP_KEY secret:DROPBOX_APP_SECRET];

    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    //Step 5. handle open url for correctly handle authorisation
    //url example: db-w5jgn38x9gg9rk8://1/connect?uid=8513459&oauth_token_secret=cbiauf7u9y10794&state=7BD0C58A-B409-4E84-BCBE-31A49A10D7F3&oauth_token=o6stzbi98q6bljws
    return [[SYScreenshotUploader sharedUploader] handleOpenURL:url];
}


- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [[DBSession sharedSession] unlinkAll];
}

@end
