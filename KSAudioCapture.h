//
//  KSAudioCapture.h
//  ScreenRecorderDemo
//
//  Created by Kevin Sum on 31/10/2016.
//  Copyright © 2016 vContent. All rights reserved.
//

#import <Foundation/Foundation.h>

@class KSAudioCapture;

@protocol KSAudioCaptureDelegate <NSObject>
@required
- (void)KSAudioCaptureDidFinishWithURL:(NSURL * _Nonnull)url successfully:(BOOL)flag;

@end

@interface KSAudioCapture : NSObject
@property _Nullable id<KSAudioCaptureDelegate> delegate;
// Permission alert description
@property  NSString * _Nullable avPermissionAlertTitle;
@property NSString * _Nullable avPermissionAlertMessage;
@property  NSString * _Nullable avPermissionAlertOK;
@property NSString * _Nullable avPermissionAlertSetting;

@property (nonatomic) BOOL allowChangeAudioSession;

- (_Nonnull id)initWithURL:(NSURL * _Nullable)url target:(__kindof UIViewController * _Nonnull)target setting:(NSDictionary * _Nullable)setting;
- (_Nonnull id)initWithFileName:(NSString * _Nullable)fileName target:(__kindof UIViewController * _Nonnull)target setting:(NSDictionary * _Nullable)setting;
- (void)startRecordSuccess:(void  (^ _Nullable )(void))success fail:(void (^ _Nullable)(NSError *error))fail;

- (void)pauseRecord;
- (void)stopRecord;
- (BOOL)isRecording;


@end
