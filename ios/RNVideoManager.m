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
    
    // Create composition
    AVMutableVideoComposition *mainComposition = [AVMutableVideoComposition videoComposition];
    AVMutableVideoCompositionInstruction *mainInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    
    NSMutableArray *layerInstructions = [[NSMutableArray alloc] init];
    CMTime currentTime = kCMTimeZero;
    
    // Get the first video to determine composition size
    AVAsset *firstAsset = [AVAsset assetWithURL:[NSURL fileURLWithPath:[[NSURL URLWithString:[fileNames firstObject]] path]]];
    AVAssetTrack *firstTrack = [[firstAsset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    CGSize naturalSize = firstTrack.naturalSize;
    
    // For the render size, we'll use the height as width and width as height since we know the video is rotated
    CGSize renderSize = CGSizeMake(naturalSize.height, naturalSize.width);
    
    for (id object in fileNames) {
        NSURL *fileURL = [NSURL URLWithString:object];
        
        if (fileURL) {
            NSString *filePath = [fileURL path];
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:filePath]];
                AVAssetTrack *videoAssetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
                
                if (!videoAssetTrack) continue;
                
                CMTimeRange timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
                
                // Insert tracks
                [videoTrack insertTimeRange:timeRange
                                  ofTrack:videoAssetTrack
                                   atTime:insertTime
                                    error:nil];
                
                AVAssetTrack *audioAssetTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
                if (audioAssetTrack) {
                    [audioTrack insertTimeRange:timeRange
                                      ofTrack:audioAssetTrack
                                       atTime:insertTime
                                        error:nil];
                }
                
                // Create layer instruction
                AVMutableVideoCompositionLayerInstruction *instruction = 
                    [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
                
                // Set up transform for 90-degree rotation (b=1, c=-1)
                CGAffineTransform transform = CGAffineTransformIdentity;
                
                // First translate to move the video into view after rotation
                transform = CGAffineTransformTranslate(transform, videoAssetTrack.naturalSize.height, 0);
                
                // Then apply the 90-degree rotation
                transform = CGAffineTransformRotate(transform, M_PI_2);
                
                [instruction setTransform:transform atTime:currentTime];
                [layerInstructions addObject:instruction];
                
                // Update timing
                insertTime = CMTimeAdd(insertTime, asset.duration);
                currentTime = CMTimeAdd(currentTime, asset.duration);
            }
        }
    }
    
    // Configure main composition
    mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, insertTime);
    mainInstruction.layerInstructions = layerInstructions;
    mainComposition.instructions = @[mainInstruction];
    mainComposition.frameDuration = CMTimeMake(1, 30);
    mainComposition.renderSize = renderSize;
    
    NSString* documentsDirectory = [self applicationDocumentsDirectory];
    NSString* myDocumentPath = [documentsDirectory stringByAppendingPathComponent:@"merged_video.mp4"];
    NSURL* urlVideoMain = [[NSURL alloc] initFileURLWithPath:myDocumentPath];
    
    if([[NSFileManager defaultManager] fileExistsAtPath:myDocumentPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:myDocumentPath error:nil];
    }
    
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition 
                                                                     presetName:AVAssetExportPresetHighestQuality];
    exporter.outputURL = urlVideoMain;
    exporter.outputFileType = @"com.apple.quicktime-movie";
    exporter.shouldOptimizeForNetworkUse = YES;
    exporter.videoComposition = mainComposition;
    
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        switch ([exporter status]) {
            case AVAssetExportSessionStatusFailed:
                reject(@"event_failure", @"merge video error", nil);
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
