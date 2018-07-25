//
//  THCaptureUtilities.m
//  ScreenCaptureViewTest
//
//  Created by wayne li on 11-9-8.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import "THCaptureUtilities.h"


@implementation THCaptureUtilities

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
+ (BOOL)mergeVideo:(NSString *)videoPath andAudio:(NSString *)audioPath andTarget:(id)target andAction:(SEL)action
{
    NSURL *audioUrl=[NSURL fileURLWithPath:audioPath];
	NSURL *videoUrl=[NSURL fileURLWithPath:videoPath];
	
	AVURLAsset* audioAsset = [[AVURLAsset alloc]initWithURL:audioUrl options:nil];
	AVURLAsset* videoAsset = [[AVURLAsset alloc]initWithURL:videoUrl options:nil];
	
	//混合音乐
	AVMutableComposition* mixComposition = [AVMutableComposition composition];
	AVMutableCompositionTrack *compositionCommentaryTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio 
																						preferredTrackID:kCMPersistentTrackID_Invalid];

    NSArray *audioTracks = [audioAsset tracksWithMediaType:AVMediaTypeAudio];
    if (audioTracks.count == 0) {
        if ([target respondsToSelector:action])
        {
            NSError *error = [[NSError alloc] initWithDomain:@"com.KSScreenCapture.error" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Cannot access audio tracks"}];
            [target performSelector:action withObject:nil withObject:error];
        }
        return NO;
    }
    AVAssetTrack *audioTrack = [audioTracks firstObject];
    if (audioTracks == nil) {
        NSError *error = [[NSError alloc] initWithDomain:@"com.KSScreenCapture.error" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"First audio track does not exist"}];
        return NO;
    }
    NSError *error = nil;
	[compositionCommentaryTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioAsset.duration)
										ofTrack:audioTrack atTime:kCMTimeZero error:&error];
    if (error != nil) {
        // your completion code here
        if ([target respondsToSelector:action])
        {
            [target performSelector:action withObject:nil withObject:error];
        }
    }

	
	//混合视频
	AVMutableCompositionTrack *compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo 
																				   preferredTrackID:kCMPersistentTrackID_Invalid];
	[compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration) 
								   ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] 
									atTime:kCMTimeZero error:nil];
	AVAssetExportSession* _assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition 
																		  presetName:AVAssetExportPresetPassthrough];   
	
	//[audioAsset release];
    //[videoAsset release];
    
	//保存混合后的文件的过程
	NSString* videoName = @"export.mov";
	NSString *exportPath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:videoName];
	NSURL    *exportUrl = [NSURL fileURLWithPath:exportPath];
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:exportPath])
	{
        NSError *error = nil;
		[[NSFileManager defaultManager] removeItemAtPath:exportPath error:&error];
        if (error != nil) {
            // your completion code here
            if ([target respondsToSelector:action])
            {
                [target performSelector:action withObject:nil withObject:error];
            }
        }
	}
	
	_assetExport.outputFileType = @"com.apple.quicktime-movie";
	_assetExport.outputURL = exportUrl;
	_assetExport.shouldOptimizeForNetworkUse = YES;
	
	[_assetExport exportAsynchronouslyWithCompletionHandler:
	 ^(void ) 
    {    
		 // your completion code here
		 if ([target respondsToSelector:action]) 
         {
             [target performSelector:action withObject:exportPath withObject:nil];
		 }
     }];
    
	//[_assetExport release];
    return YES;
}
#pragma clang diagnostic pop 

@end
