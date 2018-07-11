//
//  KSScreenCapture.m
//  ScreenRecorderDemo
//
//  Created by Kevin Sum on 31/10/2016.
//  Copyright © 2016 vContent. All rights reserved.
//

#import "KSScreenCapture.h"
#import "KSAudioCapture.h"
#import <Photos/PHPhotoLibrary.h>

@interface KSScreenCapture () <THCaptureDelegate, KSAudioCaptureDelegate>
@property (nonatomic, strong) THCapture *capture;
@property (nonatomic, strong) NSString *videoPath;
@property (nonatomic, strong) NSString *audioPath;
@property (nonatomic, weak) UIViewController *target;
@end

static NSString *animationKey = @"KSHighlightAnimation";

@implementation KSScreenCapture

#pragma mark - Initialize methods

- (id)initWithTarget:(__kindof UIViewController *)target {
    if (!self) {
        self = [super init];
    }
    self.highlighted = YES;
    self.target = target;
    if (!self.capture) {
        self.capture = [[THCapture alloc] init];
        self.capture.delegate = self;
    }
    self.muted = NO;
    return self;
}

- (id)initWithTarget:(__kindof UIViewController *)target CaptureLayer:(CALayer *)layer {
    self = [self initWithTarget:target];
    self.capture.captureView = target.view;
    return self;
}

- (void)configAudioCapture {
    self.audioCapture = [[KSAudioCapture alloc] initWithFileName:nil target:_target setting:nil];
    self.audioCapture.delegate = self;
}

#pragma mark - Global config methods

- (void)setFrameRate:(NSUInteger)rate {
    self.capture.frameRate = rate;
}

#pragma mark - Capture methods

- (void)startRecordSuccess:(void (^)(void))success fail:(void (^)(void))fail {
    // Initialize the audio capture.
    if (!_muted && !_audioCapture) {
        [self configAudioCapture];
    } else if (_muted) {
        _audioCapture = nil;
    }
    // Start capture with audio recorder or directly if muted.
    void (^recordBlock)(void) = ^{
        if ([_capture startRecording1] && success) {
            success();
            if (_highlighted) {
                [self highlightRecordView];
            }
        } else if (fail) {
            fail();
        }
    };
    if (_audioCapture) {
        [_audioCapture startRecordSuccess:^{
            recordBlock();
        } fail:^{
            DDLogError(@"Start audio record error.");
            if (fail) {
                fail();
            }
        }];
    } else {
        recordBlock();
    }
}

- (void)stopRecord {
    [self.capture stopRecording];
    [self.capture.captureView.layer removeAnimationForKey:animationKey];
    if (self.audioCapture) {
        [self.audioCapture stopRecord];
    }
}

- (void)highlightRecordView {
    // Set the record view layer highlight animation
    [self.capture.captureView.layer setBorderWidth:3.0];
    [self.capture.captureView.layer setBorderColor:[UIColor clearColor].CGColor];
    CABasicAnimation *colorAnimation = [CABasicAnimation animationWithKeyPath:@"borderColor"];
    colorAnimation.fromValue = (id)[UIColor clearColor].CGColor;
    colorAnimation.toValue = (id)[UIColor redColor].CGColor;
    colorAnimation.duration = 1.0;
    colorAnimation.autoreverses = YES;
    colorAnimation.repeatCount = HUGE_VALF;
    colorAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [self.capture.captureView.layer addAnimation:colorAnimation forKey:animationKey];
}

#pragma mark - File methods

- (void)mergeVideo:(NSString *)videoPath audio:(NSString *)audioPath {
    if (videoPath) {
        _videoPath = videoPath;
    }
    if (audioPath) {
        _audioPath = audioPath;
    }
    if (_videoPath && _audioPath) {
        [THCaptureUtilities mergeVideo:_videoPath andAudio:_audioPath andTarget:self andAction:@selector(mergeDidFinish:WithError:)];
    }
}

- (void)mergeDidFinish:(NSString *)outputPath WithError:(NSError *)error {
	if (!error) {
		DDLogInfo(@"Merge finished: %@.", outputPath);
		//Remove the source file
		if ([[NSFileManager defaultManager] fileExistsAtPath:_videoPath]) {
			[[NSFileManager defaultManager] removeItemAtPath:_videoPath error:nil];
		}
		if ([[NSFileManager defaultManager] fileExistsAtPath:_audioPath]) {
			[[NSFileManager defaultManager] removeItemAtPath:_audioPath error:nil];
		}
	} else {
		DDLogError(@"Merge Error: ", error.localizedDescription);
	}
	[self exportVideo:outputPath];
}

- (void)exportVideo:(NSString *)path {
	//Create thumbnails
	AVURLAsset *videoAsset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:path] options:nil];
	AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:videoAsset];
	gen.appliesPreferredTrackTransform = YES;
	CMTime time = CMTimeMakeWithSeconds(0.0, 600);
	CMTime actualTime;
	CGImageRef image = [gen copyCGImageAtTime:time actualTime:&actualTime error:nil];
	UIImage *thumb = [[UIImage alloc] initWithCGImage:image];
	CGImageRelease(image);
	
    if ([_delegate respondsToSelector:@selector(KSScreenCaptureDidFinish:path:thumb:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
			[_delegate KSScreenCaptureDidFinish:self path:path thumb:thumb];
        });
    }
}

- (void)saveVideoAtPathToSavedPhotosAlbum:(NSString *)path completeSeletor:(SEL)action {
    if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(path)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                switch (status) {
                    case PHAuthorizationStatusAuthorized:
                        UISaveVideoAtPathToSavedPhotosAlbum(path, _delegate, action, nil);
                        break;
                    case PHAuthorizationStatusDenied:
                        [self savePhotosAlbumAlert];
                        break;
                    default:
                        DDLogInfo(@"Save video fail since not determine authorization status.");
                        break;
                }
            }];
        });
    }
}

- (void)savePhotosAlbumAlert {
    _phPermissionAlertTitle = _phPermissionAlertTitle?:NSLocalizedString(@"Warning!", nil);
    _phPermissionAlertMessage = _phPermissionAlertMessage?:NSLocalizedString(@"Please grant the photo album permission.", nil);
    _phPermissionAlertOK = _phPermissionAlertOK?:NSLocalizedString(@"OK", nil);
    _phPermissionAlertSetting = _phPermissionAlertSetting?:NSLocalizedString(@"Setting", nil);
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:_phPermissionAlertTitle message:_phPermissionAlertMessage preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:_phPermissionAlertSetting style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSURL *settingURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
        if ([[UIApplication sharedApplication] canOpenURL:settingURL]) {
            [[UIApplication sharedApplication] openURL:settingURL];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:_phPermissionAlertOK style:UIAlertActionStyleCancel handler:nil]];
    [_target presentViewController:alert animated:YES completion:nil];
}

#pragma mark - THCaptureDelegate methods

- (void)recordingFinished:(NSString *)outputPath {
    DDLogInfo(@"Record finished: %@.", outputPath);
    if (!_audioCapture) {
        // If there is no audio capture, export the video path directly
        [self exportVideo:outputPath];
    }
    else {
        [self mergeVideo:outputPath audio:nil];
    }
}

- (void)recordingFaild:(NSError *)error {
    DDLogError(@"Record failed: %@", error);
}

#pragma mark - KSAudioCaptureDelegate methods

- (void)KSAudioCaptureDidFinishWithURL:(NSURL *)url successfully:(BOOL)flag {
    DDLogInfo(@"Audio record finished: %@.", url);
    [self mergeVideo:nil audio:[url absoluteString]];
}

@end
