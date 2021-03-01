#import <AVFoundation/AVFoundation.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTBridgeModule.h>

#import <React/RCTBridge+Private.h>
#import <React/RCTUtils.h>
#import <jsi/jsi.h>

@interface Recording : RCTEventEmitter <RCTBridgeModule>
- (void)processInputBuffer:(AudioQueueBufferRef)inBuffer queue:(AudioQueueRef)queue;
@property (nonatomic, assign) BOOL setBridgeOnMainQueue;
@end
