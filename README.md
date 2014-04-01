SYScreenshotUploader
====================

Small component for iOS developers who send screenshots to designers very often and hate the process of opening Photos app and sending photos via iMessage or email. Uploader detects any screenshot that user make and uploads it to Dropbox. There you can share folder or just send screens without pain.

##Integration

###Import uploader and dropbox files

Drag and drop SYScreenshotUploader.h, SYScreenshotUploader.m files into your project. Download DropboxSDK.framework at https://www.dropbox.com/developers/core/sdks/ios and drag and drop framework file into your project.  

###Create Dropbox app

Go to https://www.dropbox.com/developers/apps/create and create new Dropbox API app. Current version of Screenshot Uploder supports only sandboxed Dropbox app. This means that it will create a folder with your new app name in dropbox root/Apps and all screenshots will be uploaded here.

Unfortunatelly, Dropbox SDK will redirect to your app using URL schemes when authorisating your app. So it means that each your app must have it's own dropbox app in order to redirect you to correct app. If you wish to have only 1 dropbox app and upload screenshots from your muplitple apps, this will not work correctly since iOS will not be able to decide where to redirect. There are 2 workarounds for this:

1. before authorising your app with Dropbox, delete all other apps that uses Screenshot Uplaoder.
2. contact Dropbox and ask them to implement custom URL schemes support.

###Register URL Scheme

Register your dropbox's app to correct URL scheme (db-DROPBOX_APP_KEY) in Info.plist. This will ensure that after successful authorisation iOS will redirect you from Dropbox app to your app.

###Link with AssetsLibrary.framework
Go to your project's target -> Link Binary With Libraries add AssetsLibrary.framework

###Implementation

In your app's app delegate implementation file import header and define keys

```objC
#import "SYScreenshotUploader.h"
#define DROPBOX_APP_KEY @"your dropbox app key"
#define DROPBOX_APP_SECRET @"your dropbox app secret"
```

Initiate shared uploader and pass Dropbox keys:

```objC
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[SYScreenshotUploader sharedUploader] setDropboxAppKey:DROPBOX_APP_KEY secret:DROPBOX_APP_SECRET];
    return YES;
}
``` 
 
Handle open url for correctly handle authorisation:

```objC
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    return [[SYScreenshotUploader sharedUploader] handleOpenURL:url];
}
```
