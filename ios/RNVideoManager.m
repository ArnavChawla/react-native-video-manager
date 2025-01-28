
#import "RNVideoManager.h"

@implementation RNVideoManager

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(merge:(NSArray *)fileNames
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    
    NSLog(@"%@ %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
    
    [self MergeVideo:fileNames resolver:resolve rejecter:reject];
}

-(void)LoopVideo:(NSArray *)fileNames callback:(RCTResponseSenderBlock)successCallback
{
    for (id object in fileNames)
    {
        NSLog(@"video: %@", object);
    }
}

-(void)MergeVideo:(NSArray *)fileNames resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject
{
    
    CGFloat totalDuration;
    totalDuration = 0;
    
    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
    
    AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                        preferredTrackID:kCMPersistentTrackID_Invalid];
    
    AVMutableCompositionTrack *audioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                        preferredTrackID:kCMPersistentTrackID_Invalid];
    
    CMTime insertTime = kCMTimeZero;
    CGAffineTransform originalTransform;
    
    for (id object in fileNames) {
        NSURL *fileURL = [NSURL URLWithString:object];
        
        if (fileURL) {
            NSString *filePath = [fileURL path];
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                NSLog(@"File exists at path: %@", filePath);
                

                AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:filePath]];

                NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
                NSNumber *fileSize = fileAttributes[NSFileSize];
                if ([fileSize longLongValue] == 0) {
                    NSLog(@"Warning: The file at %@ has a size of 0 bytes.", filePath);
                    continue;
                }

                CMTimeRange timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);

                if (CMTIME_COMPARE_INLINE(asset.duration, ==, kCMTimeZero)) {
                    NSLog(@"Warning: Asset duration for %@ is zero.", filePath);
                    continue;
                }

                // Insert video and audio time ranges
                [videoTrack insertTimeRange:timeRange
                                    ofTrack:[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0]
                                     atTime:insertTime
                                      error:nil];
                
                [audioTrack insertTimeRange:timeRange
                                    ofTrack:[[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0]
                                     atTime:insertTime
                                      error:nil];
                
                // Update the insertion time for the next asset
                insertTime = CMTimeAdd(insertTime, asset.duration);
                
                // Get the first track from the asset and its transform
                NSArray* tracks = [asset tracks];
                AVAssetTrack* track = [tracks objectAtIndex:0];
                originalTransform = [track preferredTransform];
            } else {
                NSLog(@"Error: File does not exist at path: %@", filePath);
            }
        } else {
            NSLog(@"Error: Invalid NSURL for object: %@", object);
        }
    }

    
    // Use the transform from the original track to set the video track transform.
    if (originalTransform.a || originalTransform.b || originalTransform.c || originalTransform.d) {
        videoTrack.preferredTransform = originalTransform;
    }
    
    NSString* documentsDirectory= [self applicationDocumentsDirectory];
    NSString * myDocumentPath = [documentsDirectory stringByAppendingPathComponent:@"merged_video.mp4"];
    NSURL * urlVideoMain = [[NSURL alloc] initFileURLWithPath: myDocumentPath];
    
    if([[NSFileManager defaultManager] fileExistsAtPath:myDocumentPath])
    {
        [[NSFileManager defaultManager] removeItemAtPath:myDocumentPath error:nil];
    }
    
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
    exporter.outputURL = urlVideoMain;
    exporter.outputFileType = @"com.apple.quicktime-movie";
    exporter.shouldOptimizeForNetworkUse = YES;
    
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        
        switch ([exporter status])
        {
            case AVAssetExportSessionStatusFailed:
                reject(@"event_failure", @"merge video error",  nil);
                break;
                
            case AVAssetExportSessionStatusCancelled:
                break;
                
            case AVAssetExportSessionStatusCompleted:
                resolve([@"file://" stringByAppendingString:myDocumentPath]);
                break;
            default:
                break;
        }
    }];
}

- (NSString*) applicationDocumentsDirectory
{
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}

@end
  
