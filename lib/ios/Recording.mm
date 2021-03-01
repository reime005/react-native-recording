#import "Recording.h"

using namespace facebook;

@implementation Recording {
    AudioQueueRef _queue;
    AudioQueueBufferRef _buffer;
    NSNumber *_audioData[65536];
    UInt32 _bufferSize;
}

@synthesize bridge = _bridge;
@synthesize methodQueue = _methodQueue;

void inputCallback(
        void *inUserData,
        AudioQueueRef inAQ,
        AudioQueueBufferRef inBuffer,
        const AudioTimeStamp *inStartTime,
        UInt32 inNumberPacketDescriptions,
        const AudioStreamPacketDescription *inPacketDescs) {
    [(__bridge Recording *) inUserData processInputBuffer:inBuffer queue:inAQ];
}

RCT_EXPORT_MODULE()

+ (BOOL)requiresMainQueueSetup {
    return YES;
}

static jsi::Array cconvertNSArrayToJSIArray(jsi::Runtime &runtime, NSArray *value)
{
    jsi::Array result = jsi::Array(runtime, value.count);
    for (size_t i = 0; i < value.count; i++) {
        result.setValueAtIndex(runtime, i, jsi::Value([value[i] doubleValue]));
    }
    return result;
}

- (void)setBridge:(RCTBridge *)bridge
{
    _bridge = bridge;
    _setBridgeOnMainQueue = RCTIsMainQueue();

    RCTCxxBridge *cxxBridge = (RCTCxxBridge *)self.bridge;
    if (!cxxBridge.runtime) {
        return;
    }

    setup(*(jsi::Runtime *)cxxBridge.runtime);
}


static void testSend(jsi::Runtime & jsiRuntime, jsi::Array & data)
{
    if (jsiRuntime.global().hasProperty(jsiRuntime, "testRecordingListener")) {
        auto ob = jsiRuntime.global().getPropertyAsFunction(jsiRuntime, "testRecordingListener").call(
                                                                                           jsiRuntime,
                                                                                           data);
    }
}

RCT_EXPORT_METHOD(init:(NSDictionary *) options) {
    UInt32 bufferSize = options[@"bufferSize"] == nil ? 8192 : [options[@"bufferSize"] unsignedIntegerValue];
    _bufferSize = bufferSize;

    AudioStreamBasicDescription description;
    description.mReserved = 0;
    description.mSampleRate = options[@"sampleRate"] == nil ? 44100 : [options[@"sampleRate"] doubleValue];
    description.mBitsPerChannel = options[@"bitsPerChannel"] == nil ? 16 : [options[@"bitsPerChannel"] unsignedIntegerValue];
    description.mChannelsPerFrame = options[@"channelsPerFrame"] == nil ? 1 : [options[@"channelsPerFrame"] unsignedIntegerValue];
    description.mFramesPerPacket = options[@"framesPerPacket"] == nil ? 1 : [options[@"framesPerPacket"] unsignedIntegerValue];
    description.mBytesPerFrame = options[@"bytesPerFrame"] == nil ? 2 : [options[@"bytesPerFrame"] unsignedIntegerValue];
    description.mBytesPerPacket = options[@"bytesPerPacket"] == nil ? 2 : [options[@"bytesPerPacket"] unsignedIntegerValue];
    description.mFormatID = kAudioFormatLinearPCM;
    description.mFormatFlags = kAudioFormatFlagIsSignedInteger;

    AudioQueueNewInput(&description, inputCallback, (__bridge void *) self, NULL, NULL, 0, &_queue);
    AudioQueueAllocateBuffer(_queue, (UInt32) (bufferSize * 2), &_buffer);
    AudioQueueEnqueueBuffer(_queue, _buffer, 0, NULL);
}

RCT_EXPORT_METHOD(start) {
    AudioQueueStart(_queue, NULL);
}

RCT_EXPORT_METHOD(stop) {
    AudioQueueStop(_queue, YES);
}

- (void)processInputBuffer:(AudioQueueBufferRef)inBuffer queue:(AudioQueueRef)queue {
    SInt16 *audioData = (SInt16*) inBuffer->mAudioData;
    UInt32 count = inBuffer->mAudioDataByteSize / sizeof(SInt16);
    for (int i = 0; i < _bufferSize; i++) {
        _audioData[i] = @(audioData[i]);
    }

    RCTCxxBridge *cxxBridge = (RCTCxxBridge *)self.bridge;

    if (!cxxBridge.runtime) {
        [self sendEventWithName:@"recording" body:[NSArray arrayWithObjects:_audioData count:count]];
    } else {
        jsi::Array arr = cconvertNSArrayToJSIArray(*(jsi::Runtime *)cxxBridge.runtime, [NSArray arrayWithObjects:_audioData count:count]);
        testSend(*(jsi::Runtime *)cxxBridge.runtime, arr);
    }

    AudioQueueEnqueueBuffer(queue, inBuffer, 0, NULL);
}

- (NSArray<NSString *> *)supportedEvents {
    return @[@"recording"];
}

- (void)dealloc {
    AudioQueueStop(_queue, YES);
}

@end
