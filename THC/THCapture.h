//
//  THCapture.h
//  ScreenCaptureViewTest
//
//  Created by wayne li on 11-8-24.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "THCaptureUtilities.h"
@protocol THCaptureDelegate;
@interface THCapture : NSObject
@property(nonatomic, assign) NSUInteger frameRate;
@property(nonatomic, assign) float spaceDate;//秒
@property(nonatomic, assign) UIView *captureView;
@property(nonatomic, strong) id<THCaptureDelegate> delegate;

//开始录制
- (bool)startRecording1;
//结束录制
- (void)stopRecording;

@end


@protocol THCaptureDelegate <NSObject>

- (void)recordingFinished:(NSString*)outputPath;
- (void)recordingFailed:(NSError *)error;
- (UIImage *)captureImageFromDelegate;

@end
