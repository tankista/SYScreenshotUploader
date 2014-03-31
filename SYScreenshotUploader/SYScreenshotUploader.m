//
//  SYScreenshotUploader.m
//  Synopsi
//
//  Created by Peter Stajger on 31/01/14.
//  Copyright (c) 2014 SynopsiTV. All rights reserved.
//

#import "SYScreenshotUploader.h"
#import <DropboxSDK/DropboxSDK.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import <objc/runtime.h>

#define DEFAULT_HIDE_UPLOAD_VIEW_DELAY 4
#define DEFAULT_ANIMATION_DURATION 0.25

@interface SYUploadScreenshotView : UIToolbar

- (void)addTargetForTouchUpInside:(id)target action:(SEL)action;
- (void)beginProgress;
- (void)endProgress;
- (void)setUploadProgress:(CGFloat)progress animated:(BOOL)animated;

@end

@interface SYScreenshotUploader () <DBRestClientDelegate, DBSessionDelegate>

@property (nonatomic, readonly) UIWindow* window;
@property (nonatomic, readonly) SYUploadScreenshotView* uploadScreenshotView;   //TODO: probably make this public for customizations
@property (nonatomic, readonly) DBRestClient *restClient;

void SYAlertNoTitle(NSString* message);

@end

@interface UIApplication (OpenUrlSwizzle)

- (BOOL)SYSU_openURL:(NSURL *)URL;

@end

@implementation UIApplication (OpenUrlSwizzle)

- (BOOL)SYSU_openURL:(NSURL *)URL;
{
    NSLog(@"%@", URL);
    return [self SYSU_openURL:URL];
}

@end

@implementation SYScreenshotUploader
{
    ALAssetsLibrary*    _assetsLibrary;
    BOOL                _isLinkingDropboxInProgress;
    BOOL                _isShowingUploadScreenshotView;
    UIImage*            _lastTakenScreenshot;
}

@synthesize restClient = _restClient;
@synthesize uploadScreenshotView = _uploadScreenshotView;

- (id)init
{
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleScreenshot:)
                                                     name:UIApplicationUserDidTakeScreenshotNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

static inline void Swizzle(Class c, SEL orig, SEL new)
{
    Method origMethod = class_getInstanceMethod(c, orig);
    Method newMethod = class_getInstanceMethod(c, new);
    if(class_addMethod(c, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
        class_replaceMethod(c, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    else
        method_exchangeImplementations(origMethod, newMethod);
}

#pragma mark
#pragma mark Public Class Methods

+ (instancetype)sharedUploader
{
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
        Swizzle([UIApplication class], @selector(openURL:), @selector(SYSU_openURL:));
    });
    
    return sharedInstance;
}

- (void)setDropboxAppKey:(NSString*)key secret:(NSString*)secret
{
    DBSession* session = [[DBSession alloc] initWithAppKey:key
                                                 appSecret:secret
                                                      root:kDBRootAppFolder];
	session.delegate = [SYScreenshotUploader sharedUploader];
	[DBSession setSharedSession:session];
}

- (BOOL)handleOpenURL:(NSURL*)url
{
    if ([[DBSession sharedSession] handleOpenURL:url]) {
        if ([[DBSession sharedSession] isLinked]) {
            _isLinkingDropboxInProgress = NO;
            [self uploadLastDetectedScreenshot];
            return YES;
        }
    }
    return NO;
}

#pragma mark
#pragma mark Private Methods

- (NSUInteger)hideUploadViewAfterDelay
{
    if (_hideUploadViewAfterDelay == 0) {
        _hideUploadViewAfterDelay = DEFAULT_HIDE_UPLOAD_VIEW_DELAY;
    }
    return _hideUploadViewAfterDelay;
}

- (NSString*)productName
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
}

- (ALAssetsLibrary *)assetsLibrary
{
    if (!_assetsLibrary) {
        _assetsLibrary = [[ALAssetsLibrary alloc] init];
    }
    return _assetsLibrary;
}

- (UIWindow *)window
{
    return [[UIApplication sharedApplication] keyWindow];
}

- (UIView *)uploadScreenshotView
{
    if (!_uploadScreenshotView) {
        CGRect screenFrame = self.window.bounds;
        CGRect frame = CGRectMake(0, 0, screenFrame.size.width, 64);
        _uploadScreenshotView = [[SYUploadScreenshotView alloc] initWithFrame:frame];
    }
    return _uploadScreenshotView;
}

- (DBRestClient *)restClient {
    if (!_restClient) {
        _restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        _restClient.delegate = self;
    }
    return _restClient;
}

- (void)uploadLastDetectedScreenshot
{
    ALAssetsLibrary *assetsLibrary = [[ALAssetsLibrary alloc] init];
    [assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        if (nil != group) {
            // be sure to filter the group so you only get photos
            [group setAssetsFilter:[ALAssetsFilter allPhotos]];
            
            [group enumerateAssetsAtIndexes:[NSIndexSet indexSetWithIndex:group.numberOfAssets - 1] options:0 usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                if (nil != result) {
                    ALAssetRepresentation *repr = [result defaultRepresentation];
                    _lastTakenScreenshot = [UIImage imageWithCGImage:[repr fullResolutionImage]];
                    
                    NSData *imageData = UIImagePNGRepresentation(_lastTakenScreenshot);
                    
                    NSString *productName = [self productName];
                    
                    NSString *fileName = [NSString stringWithFormat:@"%@-%f.png", [productName lowercaseString], [[NSDate date] timeIntervalSince1970]];
                    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
                    [imageData writeToFile:filePath atomically:YES];
                    
                    NSString *destDir = [NSString stringWithFormat:@"/%@/", productName];
                    
                    [self prepareUploadScreenshotViewForUpload];
                    
                    [self.restClient uploadFile:fileName toPath:destDir withParentRev:nil fromPath:filePath];
                    
                    *stop = YES;
                }
            }];
        }
        
        *stop = NO;
    } failureBlock:^(NSError *error) {
        SYAlertNoTitle([error localizedDescription]);
    }];
}

- (void)handleScreenshot:(NSNotification*)notification
{
    [self.uploadScreenshotView addTargetForTouchUpInside:self action:@selector(handleUploadScreenshotButton:)];
    
    [UIView cancelPreviousPerformRequestsWithTarget:self];
    [self show:YES screenshotViewAnimated:NO];
    [self hideUploadScreenshotViewAfterDelayAnimated];
}

- (void)handleUploadScreenshotButton:(UIButton*)button
{
    [UIView cancelPreviousPerformRequestsWithTarget:self];
    
    if ([[DBSession sharedSession] isLinked] == NO) {
        _isLinkingDropboxInProgress = YES;
        [[DBSession sharedSession] linkFromController:nil];
    }
    else {
        [self uploadLastDetectedScreenshot];
    }
}

#pragma mark
#pragma mark Show/Hide Screenshot View Methods

- (void)hideUploadScreenshotViewAfterDelayAnimated
{
    [self performSelector:@selector(hideUploadScreenshotViewAnimated) withObject:nil afterDelay:self.hideUploadViewAfterDelay];
}

- (void)showUploadScreenshotViewAnimated
{
    [self show:YES screenshotViewAnimated:YES];
}

- (void)hideUploadScreenshotViewAnimated
{
    [self show:NO screenshotViewAnimated:YES];
}

- (void)show:(BOOL)show screenshotViewAnimated:(BOOL)animated
{
    if ((_isShowingUploadScreenshotView && show) || (_isShowingUploadScreenshotView == NO && show == NO)) {
        return;
    }
    
    if (show) {
        CGRect frame = self.uploadScreenshotView.frame;
        frame.origin.y = - CGRectGetHeight(frame);
        self.uploadScreenshotView.frame = frame;
        [self.window addSubview:self.uploadScreenshotView];
    }

    [UIView animateWithDuration:animated?DEFAULT_ANIMATION_DURATION:0.0 animations:^{
        
        if (show) {
            CGRect frame = self.uploadScreenshotView.frame;
            frame.origin.y = 0;
            self.uploadScreenshotView.frame = frame;
            [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
        }
        else {
            CGRect frame = self.uploadScreenshotView.frame;
            frame.origin.y = - CGRectGetHeight(frame);
            self.uploadScreenshotView.frame = frame;
        }
        
    } completion:^(BOOL finished) {
        
        if (show) {
            _isShowingUploadScreenshotView = YES;
        }
        else {
            _isShowingUploadScreenshotView = NO;
            [self.uploadScreenshotView removeFromSuperview];
        }
        
    }];
}

- (void)prepareUploadScreenshotViewForUpload
{
    [self.uploadScreenshotView beginProgress];
    
    CGRect frame = self.uploadScreenshotView.frame;
    frame.origin.y = - CGRectGetHeight(frame) + 2;
    
    [UIView animateWithDuration:DEFAULT_ANIMATION_DURATION animations:^{
        
        self.uploadScreenshotView.frame = frame;
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
        
    } completion:^(BOOL finished) {
        
    }];
}

#pragma mark
#pragma mark DBSessionDelegate Methods

- (void)sessionDidReceiveAuthorizationFailure:(DBSession *)session userId:(NSString *)userId
{
    SYAlertNoTitle([NSString stringWithFormat:@"Did receive auth failure for user %@", userId]);
}

#pragma mark
#pragma mark DBRestClientDelegate Methods

- (void)restClient:(DBRestClient*)client uploadedFile:(NSString*)destPath from:(NSString*)srcPath metadata:(DBMetadata*)metadata
{
    NSLog(@"File uploaded successfully to path: %@", metadata.path);
    NSLog(@"Deleting image from temp storage: %@", srcPath);
    if ([[NSFileManager defaultManager] isDeletableFileAtPath:srcPath]) {
        NSError *deleteError = nil;
        [[NSFileManager defaultManager] removeItemAtPath:srcPath error:&deleteError];
        if (deleteError) {
            NSLog(@"Error: %@", [deleteError localizedDescription]);
        }
    }
    [self show:NO screenshotViewAnimated:YES];
    [self.uploadScreenshotView endProgress];
}

- (void)restClient:(DBRestClient*)client uploadProgress:(CGFloat)progress forFile:(NSString*)destPath from:(NSString*)srcPath
{
    [self.uploadScreenshotView setUploadProgress:progress animated:YES];
}

- (void)restClient:(DBRestClient*)client uploadFileFailedWithError:(NSError*)error {
    NSLog(@"File upload failed with error - %@", error);
    SYAlertNoTitle([error localizedDescription]);
    
    [self show:NO screenshotViewAnimated:YES];
    [self.uploadScreenshotView endProgress];
}

@end

void SYAlertNoTitle(NSString* message)
{
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:nil
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                          otherButtonTitles:nil];
    [alert show];
}

@implementation SYUploadScreenshotView
{
    UIButton*           _button;
    CALayer*            _uploadProgressLayer;
    UIProgressView*     _progressView;
}

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.barTintColor = [UIColor redColor];
        _button = [UIButton buttonWithType:UIButtonTypeCustom];
        _button.frame = CGRectZero;
        [_button setTitle:NSLocalizedString(@"Upload to Dropbox", nil) forState:UIControlStateNormal];
        [self addSubview:_button];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    BOOL viewControllerStatusBarAppearance = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIViewControllerBasedStatusBarAppearance"] boolValue];
    if (viewControllerStatusBarAppearance) {
        _button.frame = CGRectOffset(CGRectInset(self.bounds, 0, 10), 0, 10);
    }
    else {
        _button.frame = self.bounds;
    }
    
    _progressView.frame = CGRectMake(0, CGRectGetHeight(self.frame) - 2, CGRectGetWidth(self.frame), 2);
}

- (void)addTargetForTouchUpInside:(id)target action:(SEL)action
{
    [_button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
}

- (void)setUploadProgress:(CGFloat)progress animated:(BOOL)animated
{
    [_progressView setProgress:progress animated:YES];
}

- (void)beginProgress
{
    if (!_progressView) {
        _progressView = [[UIProgressView alloc] initWithFrame:CGRectZero];
        _progressView.tintColor = [UIColor blueColor];
        _progressView.alpha = 0.0;
        [self addSubview:_progressView];
    }
    
    _progressView.alpha = 1.0;
    [_progressView setProgress:0.0 animated:NO];
}

- (void)endProgress
{
    [UIView animateWithDuration:DEFAULT_ANIMATION_DURATION animations:^{
        _progressView.alpha = 0.0;
    }];
}

@end
