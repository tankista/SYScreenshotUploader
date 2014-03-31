//
//  SYAppDelegate.m
//  SYScreenshotUploader
//
//  Created by Peter Stajger on 31/03/14.
//  Copyright (c) 2014 SynopsiTV. All rights reserved.
//

#import "SYAppDelegate.h"

//Step 1. Include file and set your dropbox app key and secret
#import "SYScreenshotUploader.h"
#define DROPBOX_APP_KEY @"your app key"
#define DROPBOX_APP_SECRET @"your app secret"

//Step 2. Register your dropbox app to correct URL scheme (db-DROPBOX_APP_KEY) in Info.plist


@implementation SYAppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    //Step 3. Initialte shared uploader and set dropbox app key and secret
    [[SYScreenshotUploader sharedUploader] setDropboxAppKey:DROPBOX_APP_KEY secret:DROPBOX_APP_SECRET];

    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    //Step 4. handle open url for correctly handle authorisation
    return [[SYScreenshotUploader sharedUploader] handleOpenURL:url];
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
