//
//  SYScreenshotUploader.h
//  Synopsi
//
//  Created by Peter Stajger on 31/01/14.
//  Copyright (c) 2014 SynopsiTV. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const SYScreenshotUploaderDropboxAppKey;

@interface SYScreenshotUploader : NSObject

/**
 * Readonly access to last detected screenshot image. In case you need it.
 */
@property (nonatomic, readonly) UIImage* lastDetectedScreenshot;

/**
 * If user does not upload screenshot, send screenshot view is dismissed after a delay.
 */
@property (nonatomic, assign) NSUInteger hideUploadViewAfterDelay;


/**
 * Initiate shared uploader in your app's application:didFinishLaunchingWithOptions: method.
 */
+ (instancetype)sharedUploader;

/**
 * After shared uploader is initiated, set app key and secret of your own registered dropbox app.
 * Read more about dropbox apps at https://www.dropbox.com/developers.
 */
- (void)setDropboxAppKey:(NSString*)key secret:(NSString*)secret;

/**
 * Use this method in your app's application:openURL:sourceApplication:annotation: method.
 */
- (BOOL)handleOpenURL:(NSURL*)url;



@end