//
//  THCapture.m
//  ScreenCaptureViewTest
//
//  Created by wayne li on 11-8-24.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import "THCapture.h"
#import "CGContextCreator.h"

static NSString* const kFileName=@"output.mov";

@interface THCapture()

@property(nonatomic, strong) AVAssetWriter *videoWriter;
@property(nonatomic, strong) AVAssetWriterInput *videoWriterInput;
@property(nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *avAdaptor;
//recording state
@property(nonatomic, assign) BOOL           recording;     //正在录制中
@property(nonatomic, assign) BOOL           writing;       //正在将帧写入文件
@property(nonatomic, strong) NSDate         *startedAt;     //录制的开始时间
@property(nonatomic, strong) NSTimer        *timer;         //按帧率写屏的定时器


//配置录制环境
- (BOOL)setUpWriter;
//清理录制环境
- (void)cleanupWriter;
//完成录制工作
- (void)completeRecordingSession;
//录制每一帧
- (void)drawFrame;
@end

@implementation THCapture

- (id)init
{
    self = [super init];
    if (self) {
        self.frameRate = 100;//默认帧率为10
    }
    
    return self;
}

- (void)dealloc {
	[self cleanupWriter];
}

#pragma mark -
#pragma mark CustomMethod

- (bool)startRecording1
{
    bool result = NO;
    if (!self.recording && self.captureView)
    {
        result = [self setUpWriter];
        if (result)
        {
            self.startedAt = [NSDate date];
            self.spaceDate=0;
            self.recording = true;
            self.writing = false;
            //绘屏的定时器
            NSDate *nowDate = [NSDate date];
            self.timer = [[NSTimer alloc] initWithFireDate:nowDate interval:1.0/self.frameRate target:self selector:@selector(drawFrame) userInfo:nil repeats:YES];
            [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
        }
    }
	return result;
}

- (void)stopRecording
{
    if (_recording) {
         self.recording = false;
        [self.timer invalidate];
        _timer = nil;
        [self completeRecordingSession];
        [self cleanupWriter];
    }
}
- (void)drawFrame
{
    if (!self.writing) {
        [self performSelectorOnMainThread:@selector(getFrame) withObject:nil waitUntilDone:YES];
    }
}
- (void)writeVideoFrameAtTime:(CMTime)time addImage:(UIImage *)image
{
    if (![self.videoWriterInput isReadyForMoreMediaData]) {
#ifdef DEBUG
        NSLog(@"[KSScreenCapture] %s:%d Not ready for video data.", __PRETTY_FUNCTION__, __LINE__);
#endif
        NSError *error = [[NSError alloc] initWithDomain:@"com.KSScreenCapture.error" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Not ready for video data"}];
        if ([self.delegate respondsToSelector:@selector(recordingFailed:)]) {
            [self.delegate recordingFailed:error];
        }

	}
	else {
		@synchronized (self) {
            CGContextRef context = UIGraphicsGetCurrentContext();

            CVPixelBufferRef pixelBuffer = [self pixelBufferForImage:image];
            BOOL success = [self.avAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:time];
            if (!success) {
#ifdef DEBUG
                NSLog(@"[KSScreenCapture] %s:%d Warning:  Unable to write buffer to video.", __PRETTY_FUNCTION__, __LINE__);
#endif
            }
            if (pixelBuffer) {
                CVPixelBufferRelease(pixelBuffer);
            }
		}
	}
}


- (CVPixelBufferRef)pixelBufferForImage:(UIImage *)image
{
    CGImageRef cgImage = image.CGImage;
    
    NSDictionary *options = @{
                              (NSString *)kCVPixelBufferCGImageCompatibilityKey: @(YES),
                              (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @(YES)
                              };
    CVPixelBufferRef buffer = NULL;
    
    CVPixelBufferCreate(kCFAllocatorDefault, CGImageGetWidth(cgImage), CGImageGetHeight(cgImage), kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef)options, &buffer);
    
    CVPixelBufferLockBaseAddress(buffer, 0);
    
    void *data                  = CVPixelBufferGetBaseAddress(buffer);
    CGColorSpaceRef colorSpace  = CGColorSpaceCreateDeviceRGB();
    CGContextRef context        = CGBitmapContextCreate(data, CGImageGetWidth(cgImage), CGImageGetHeight(cgImage), 8, CVPixelBufferGetBytesPerRow(buffer), colorSpace, (kCGBitmapAlphaInfoMask & kCGImageAlphaNoneSkipFirst));
    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, CGImageGetWidth(cgImage), CGImageGetHeight(cgImage)), cgImage);
    
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    
    return buffer;
}



- (void)getFrame
{
    if (!self.writing && self.recording) {
        self.writing = true;
        size_t width  = self.captureView.frame.size.width;
        size_t height = self.captureView.frame.size.height;
        @try {
            CGSize size = CGSizeMake(width, height);
            UIImage *resultImage = nil;
            if ([self.delegate respondsToSelector:@selector(captureImageFromDelegate)]) {
                resultImage = [self.delegate captureImageFromDelegate];
            }
            if (resultImage == nil) {
                UIGraphicsBeginImageContextWithOptions(size, YES, [UIScreen mainScreen].scale);
                [self.captureView drawViewHierarchyInRect:CGRectMake(0, 0, width, height) afterScreenUpdates:NO];
                resultImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
            }
            float millisElapsed = [[NSDate date] timeIntervalSinceDate:self.startedAt] * 1000.0-self.spaceDate*1000.0;
#ifdef DEBUG
            NSLog(@"[KSScreenCapture] %s:%d seconds = %d", __PRETTY_FUNCTION__, __LINE__, (int)millisElapsed/1000);
#endif

            [self writeVideoFrameAtTime:CMTimeMake((int)millisElapsed, 1000) addImage:resultImage];
        }
        @catch (NSError *error) {
#ifdef DEBUG
            NSLog(@"[KSScreenCapture] %s:%d error = %@", __PRETTY_FUNCTION__, __LINE__, error.localizedDescription);
#endif
            if ([self.delegate respondsToSelector:@selector(recordingFailed:)]) {
                [self.delegate recordingFailed:error];
            }

        }
        self.writing = false;
    }
}

- (NSString*)tempFilePath {
    NSArray  *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *filePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:kFileName];
	
	return filePath;
}

- (BOOL)setUpWriter {
    
    CGSize size = self.captureView.layer.frame.size;
    CGSize translate = CGSizeMake(0, size.height);//The translate size for flip the context.
    //Context size must be times of 32
    if (fmodf(size.width, 32) > 0) {
        int quotient = size.width/32;
        size.width = (quotient+1)*32;
        translate.width += (size.width-self.captureView.layer.frame.size.width)/2;
    }
    if (fmodf(size.height, 32) > 0) {
        int quotient = size.height/32;
        size.height = (quotient+1)*32;
        translate.height -= (size.height-self.captureView.layer.frame.size.height)/2;
    }
    //Clear Old TempFile
	NSError  *error = nil;
    NSString *filePath=[self tempFilePath];
    NSFileManager* fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath:filePath])
    {
		if ([fileManager removeItemAtPath:filePath error:&error] == NO)
        {
#ifdef DEBUG
            NSLog(@"[KSScreenCapture] %s:%d Could not delete old recording file at path %@. Error %@.", __PRETTY_FUNCTION__, __LINE__, filePath, error.localizedDescription);
#endif
            if ([self.delegate respondsToSelector:@selector(recordingFailed:)]) {
                [self.delegate recordingFailed:error];
            }
            return NO;
		}
	}
    
    //Configure videoWriter
    NSURL   *fileUrl=[NSURL fileURLWithPath:filePath];
	_videoWriter = [[AVAssetWriter alloc] initWithURL:fileUrl fileType:AVFileTypeQuickTimeMovie error:&error];
	NSParameterAssert(self.videoWriter);
	
	//Configure videoWriterInput
	NSDictionary* videoCompressionProps = [NSDictionary dictionaryWithObjectsAndKeys:
										   [NSNumber numberWithDouble:size.width*size.height], AVVideoAverageBitRateKey,
										   nil ];
	
	NSDictionary* videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
								   AVVideoCodecH264, AVVideoCodecKey,
								   [NSNumber numberWithInt:size.width], AVVideoWidthKey,
								   [NSNumber numberWithInt:size.height], AVVideoHeightKey,
								   videoCompressionProps, AVVideoCompressionPropertiesKey,
								   nil];

	_videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
	
	NSParameterAssert(self.videoWriterInput);
	self.videoWriterInput.expectsMediaDataInRealTime = YES;
	NSDictionary* bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
									  [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
	
	_avAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.videoWriterInput sourcePixelBufferAttributes:bufferAttributes];
	
	//add input
	[self.videoWriter addInput:self.videoWriterInput];
	[self.videoWriter startWriting];
	[self.videoWriter startSessionAtSourceTime:CMTimeMake(0, 1000)];
    
    
	return YES;
}

- (void)cleanupWriter {
   
	_avAdaptor = nil;
	
	_videoWriterInput = nil;
	
	_videoWriter = nil;
	
	_startedAt = nil;
}

- (void)completeRecordingSession {
     
	
	[self.videoWriterInput markAsFinished];
	
	// Wait for the video
	int status = self.videoWriter.status;
	while (status == AVAssetWriterStatusUnknown)
    {
#ifdef DEBUG
        NSLog(@"[KSScreenCapture] %s:%d Waiting...", __PRETTY_FUNCTION__, __LINE__);
#endif
        [NSThread sleepForTimeInterval:0.5f];
		status = self.videoWriter.status;
	}
	
    [self.videoWriter finishWritingWithCompletionHandler:^{
        if ([self.delegate respondsToSelector:@selector(recordingFinished:)]) {
            [self.delegate recordingFinished:[self tempFilePath]];
        }        
    }];
    
    
}

@end
