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

@interface SYSendScreenshotView : UIView

- (void)setUploadProgress:(CGFloat)progress animated:(BOOL)animated;
- (void)addTargetForTouchUpInside:(id)target action:(SEL)action;
- (void)beginProgress;
- (void)endProgress;

@end

@interface SYScreenshotUploader () <DBRestClientDelegate, DBSessionDelegate>

@property (nonatomic, readonly) UIWindow* window;
@property (nonatomic, readonly) SYSendScreenshotView* sendScreenshotView;
@property (nonatomic, readonly) DBRestClient *restClient;

void SYAlertNoTitle(NSString* message);

@end

@implementation SYScreenshotUploader
{
    BOOL    _isShowingSendScreenshotView;
    BOOL    _isLinkingDropboxInProgress;
    ALAssetsLibrary*    _assetsLibrary;
    UIImage*    _lastTakenScreenshot;
}

@synthesize sendScreenshotView = _sendScreenshotView;
@synthesize restClient = _restClient;

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

#pragma mark
#pragma mark Public Class Methods

+ (instancetype)sharedUploader
{
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
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
                    
                    NSString *fileName = [NSString stringWithFormat:@"screenshot-%f.png", [[NSDate date] timeIntervalSince1970]];
                    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
                    [imageData writeToFile:filePath atomically:YES];
                    
                    NSString *destDir = [NSString stringWithFormat:@"/%@/", [self productName]];
                    
                    [self prepareScreenshotViewForUpload];
                    
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

- (DBRestClient *)restClient {
    if (!_restClient) {
        _restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        _restClient.delegate = self;
    }
    return _restClient;
}

- (void)handleScreenshot:(NSNotification*)notification
{
    [self.sendScreenshotView addTargetForTouchUpInside:self action:@selector(handleSendScreenshotButton:)];
    
    [UIView cancelPreviousPerformRequestsWithTarget:self];
    [self show:YES screenshotViewAnimated:NO];
    [self hideSendScreenshotViewAfterDelayAnimated];
}

- (void)handleSendScreenshotButton:(UIButton*)button
{
    [UIView cancelPreviousPerformRequestsWithTarget:self];
    
    if ([[DBSession sharedSession] isLinked] == NO) {
        [[DBSession sharedSession] linkFromController:nil];
        _isLinkingDropboxInProgress = YES;
    }
    else {
        [self uploadLastDetectedScreenshot];
    }
}

- (UIWindow *)window
{
    return [[UIApplication sharedApplication] keyWindow];
}

- (UIView *)sendScreenshotView
{
    if (!_sendScreenshotView) {
        CGRect screenFrame = self.window.bounds;
        CGRect frame = CGRectMake(0, 0, screenFrame.size.width, 64);
        _sendScreenshotView = [[SYSendScreenshotView alloc] initWithFrame:frame];
    }
    return _sendScreenshotView;
}

#pragma mark
#pragma mark Show/Hide Screenshot View Methods

- (void)hideSendScreenshotViewAfterDelayAnimated
{
    [self performSelector:@selector(hideSendScreenshotViewAnimated) withObject:nil afterDelay:4];
}

- (void)showSendScreenshotViewAnimated
{
    [self show:YES screenshotViewAnimated:YES];
}

- (void)hideSendScreenshotViewAnimated
{
    [self show:NO screenshotViewAnimated:YES];
}

- (void)show:(BOOL)show screenshotViewAnimated:(BOOL)animated
{
    if ((_isShowingSendScreenshotView && show) || (_isShowingSendScreenshotView == NO && show == NO)) {
        return;
    }
    
    if (show) {
        CGRect frame = self.sendScreenshotView.frame;
        frame.origin.y = - CGRectGetHeight(frame);
        self.sendScreenshotView.frame = frame;
        [self.window addSubview:self.sendScreenshotView];
    }

    [UIView animateWithDuration:animated?0.3:0.0 animations:^{
        
        if (show) {
            CGRect frame = self.sendScreenshotView.frame;
            frame.origin.y = 0;
            self.sendScreenshotView.frame = frame;
        }
        else {
            CGRect frame = self.sendScreenshotView.frame;
            frame.origin.y = - CGRectGetHeight(frame);
            self.sendScreenshotView.frame = frame;
        }
        
    } completion:^(BOOL finished) {
        
        if (show) {
            _isShowingSendScreenshotView = YES;
        }
        else {
            _isShowingSendScreenshotView = NO;
            [self.sendScreenshotView removeFromSuperview];
        }
        
    }];
}

- (void)prepareScreenshotViewForUpload
{
    [self.sendScreenshotView beginProgress];
    
    CGRect frame = self.sendScreenshotView.frame;
    frame.origin.y = - CGRectGetHeight(frame) + 2;
    
    [UIView animateWithDuration:0.3 animations:^{
        
        self.sendScreenshotView.frame = frame;
        
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
    [self.sendScreenshotView endProgress];
}

- (void)restClient:(DBRestClient*)client uploadProgress:(CGFloat)progress forFile:(NSString*)destPath from:(NSString*)srcPath
{
    [self.sendScreenshotView setUploadProgress:progress animated:YES];
}

- (void)restClient:(DBRestClient*)client uploadFileFailedWithError:(NSError*)error {
    NSLog(@"File upload failed with error - %@", error);
    SYAlertNoTitle([error localizedDescription]);
    
    [self show:NO screenshotViewAnimated:YES];
    [self.sendScreenshotView endProgress];
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

@implementation SYSendScreenshotView
{
    UIButton*   _button;
    CALayer*    _uploadProgressLayer;
    UIProgressView* _progressView;
}

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor redColor];
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
    
    _button.frame = CGRectOffset(CGRectInset(self.bounds, 0, 10), 0, 10);
}

- (void)addTargetForTouchUpInside:(id)target action:(SEL)action
{
    [_button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
}

- (void)setUploadProgress:(CGFloat)progress animated:(BOOL)animated
{
    if (!_progressView) {
        _progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.frame) - 2, CGRectGetWidth(self.frame), 2)];
        _progressView.tintColor = [UIColor blueColor];
    }
    
    [_progressView setProgress:progress animated:YES];
}

- (void)beginProgress
{
    [self addSubview:_progressView];
}

- (void)endProgress
{
    [_progressView removeFromSuperview];
}

#pragma mark
#pragma mark Private Methods

@end
