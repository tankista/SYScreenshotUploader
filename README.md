SYScreenshotUploader
====================

Small component for iOS apps that detects screenshot and upload it to linked dropbox folder. This is development tool that should help sharing screenshots between developers and designers.

##Integration

1. drag and drop SYScreenshotUploader.h/.m files into your project
2. download DropboxSDK framework and drag'n drop it int your project
3. create a Dropbox application at https://www.dropbox.com/developers/apps/create. App must be sandboxed Dropbox API app.
4. In your app's app delegate import main .h file #import "SYScreenshotUploader.h"
5. Register your dropbox's app to correct URL scheme (db-YOUR_DROPBOX_APP_KEY) in Info.plist
6. Initiate shared uploader and set Dropbox keys

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[SYScreenshotUploader sharedUploader] setDropboxAppKey:DROPBOX_APP_KEY secret:DROPBOX_APP_SECRET];

    return YES;
}
 
7. Handle open url for correctly handle authorisation

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    return [[SYScreenshotUploader sharedUploader] handleOpenURL:url];
}
