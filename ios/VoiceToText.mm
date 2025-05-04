#import "VoiceToText.h"
#import <AVFoundation/AVFoundation.h>
#import <Speech/Speech.h>
#import <React/RCTLog.h>

@interface VoiceToText ()

@property (nonatomic, copy) RCTPromiseResolveBlock stopPromiseResolve;
@property (nonatomic, copy) RCTPromiseRejectBlock stopPromiseReject;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *eventListeners;

@end

@implementation VoiceToText {
    bool hasListeners;
}

RCT_EXPORT_MODULE(VoiceToText)

+ (BOOL)requiresMainQueueSetup {
    return YES;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isListening = NO;
        _audioEngine = [[AVAudioEngine alloc] init];
        self.eventListeners = [NSMutableDictionary new];

        [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
            dispatch_async(dispatch_get_main_queue(), ^{
                switch (status) {
                    case SFSpeechRecognizerAuthorizationStatusAuthorized:
                        break;
                    case SFSpeechRecognizerAuthorizationStatusDenied:
                        [self sendEventWithName:@"onSpeechError" body:@{@"message": @"Permission denied", @"code": @(-1)}];
                        break;
                    case SFSpeechRecognizerAuthorizationStatusRestricted:
                        [self sendEventWithName:@"onSpeechError" body:@{@"message": @"Restricted", @"code": @(-2)}];
                        break;
                    case SFSpeechRecognizerAuthorizationStatusNotDetermined:
                        [self sendEventWithName:@"onSpeechError" body:@{@"message": @"Not determined", @"code": @(-3)}];
                        break;
                }
            });
        }];
    }
    return self;
}

- (NSArray<NSString *> *)supportedEvents {
    return @[
        @"onSpeechStart",
        @"onSpeechBegin",
        @"onSpeechEnd",
        @"onSpeechResults",
        @"onSpeechPartialResults",
        @"onSpeechError",
        @"onSpeechVolumeChanged",
        @"onSpeechEvent",
        @"onSpeechAudioBuffer"
    ];
}

- (void)startObserving {
    hasListeners = YES;
}

- (void)stopObserving {
    hasListeners = NO;
}

- (void)sendEventWithName:(NSString *)name body:(id)body {
    if (hasListeners) {
        [super sendEventWithName:name body:body];
    }
}

- (void)setupAudioSession {
    NSError *error = nil;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryRecord error:&error];
    if (error) {
        [self sendEventWithName:@"onSpeechError" body:@{@"message": error.localizedDescription, @"code": @(-100)}];
        return;
    }

    [audioSession setMode:AVAudioSessionModeMeasurement error:&error];
    if (error) {
        [self sendEventWithName:@"onSpeechError" body:@{@"message": error.localizedDescription, @"code": @(-101)}];
        return;
    }

    [audioSession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
    if (error) {
        [self sendEventWithName:@"onSpeechError" body:@{@"message": error.localizedDescription, @"code": @(-102)}];
    }
}

RCT_EXPORT_METHOD(startListening:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    if (_isListening) {
        reject(@"ALREADY_LISTENING", @"Already listening", nil);
        return;
    }

    NSLocale *locale = [NSLocale currentLocale];
    _speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:locale];

    if (!_speechRecognizer || !_speechRecognizer.isAvailable) {
        reject(@"NOT_AVAILABLE", @"Recognizer not available", nil);
        return;
    }

    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (status != SFSpeechRecognizerAuthorizationStatusAuthorized) {
                reject(@"PERMISSION_DENIED", @"Not authorized", nil);
                return;
            }

            [self setupAudioSession];

            if (self.recognitionTask) {
                [self.recognitionTask cancel];
                self.recognitionTask = nil;
            }

            self.recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
            self.recognitionRequest.shouldReportPartialResults = YES;

            AVAudioInputNode *inputNode = self.audioEngine.inputNode;

            self.recognitionTask = [self.speechRecognizer recognitionTaskWithRequest:self.recognitionRequest
                                                                    resultHandler:^(SFSpeechRecognitionResult *result, NSError *error) {
                BOOL isFinal = NO;

                if (result) {
                    isFinal = result.isFinal;

                    NSString *text = result.bestTranscription.formattedString;
                    NSMutableArray *transcriptions = [NSMutableArray new];

                    for (SFTranscription *t in result.transcriptions) {
                        NSMutableDictionary *transcriptionDict = [@{@"text": t.formattedString} mutableCopy];
                        [transcriptions addObject:transcriptionDict];
                    }

                    NSDictionary *payload = @{
                        @"results": @{
                            @"transcriptions": transcriptions,
                            @"value": text
                        },
                        @"value": text
                    };

                    if (isFinal) {
                        [self sendEventWithName:@"onSpeechResults" body:payload];
                    } else {
                        [self sendEventWithName:@"onSpeechPartialResults" body:payload];
                    }
                }

                if (error || isFinal) {
                    [self.audioEngine stop];
                    [inputNode removeTapOnBus:0];

                    self.recognitionRequest = nil;
                    self.recognitionTask = nil;
                    self.isListening = NO;

                    if (error) {
                        [self sendEventWithName:@"onSpeechError" body:@{@"message": error.localizedDescription, @"code": @(error.code)}];
                        if (self.stopPromiseReject) {
                            self.stopPromiseReject(@"RECOGNITION_ERROR", error.localizedDescription, error);
                        }
                    } else if (isFinal) {
                        if (self.stopPromiseResolve) {
                            self.stopPromiseResolve(@"Final result received.");
                        }
                    }

                    self.stopPromiseResolve = nil;
                    self.stopPromiseReject = nil;

                    [self sendEventWithName:@"onSpeechEnd" body:nil];
                }
            }];

            [inputNode installTapOnBus:0 bufferSize:1024 format:[inputNode outputFormatForBus:0]
                                  block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
                [self.recognitionRequest appendAudioPCMBuffer:buffer];
            }];

            [self.audioEngine prepare];
            NSError *audioError = nil;
            if (![self.audioEngine startAndReturnError:&audioError]) {
                reject(@"AUDIO_ERROR", audioError.localizedDescription, audioError);
                return;
            }

            self.isListening = YES;
            [self sendEventWithName:@"onSpeechStart" body:nil];
            resolve(@"Started listening");
        });
    }];
}

RCT_EXPORT_METHOD(stopListening:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    if (!_isListening) {
        reject(@"NOT_LISTENING", @"Not listening", nil);
        return;
    }

    _isListening = NO;
    [_audioEngine stop];
    [_audioEngine.inputNode removeTapOnBus:0];
    [_recognitionRequest endAudio];

    self.stopPromiseResolve = resolve;
    self.stopPromiseReject = reject;
}

RCT_EXPORT_METHOD(destroy:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    [_audioEngine stop];
    [_audioEngine.inputNode removeTapOnBus:0];

    _recognitionRequest = nil;
    _recognitionTask = nil;
    _speechRecognizer = nil;
    _isListening = NO;

    [self.eventListeners removeAllObjects];

    resolve(@"Speech recognizer destroyed");
}

- (void)addListener:(NSString *)eventName {
    NSNumber *count = self.eventListeners[eventName];
    self.eventListeners[eventName] = @(count ? count.intValue + 1 : 1);
}

- (void)removeListeners:(double)count {
    NSInteger removeCount = (NSInteger)count;
    for (NSString *key in [self.eventListeners allKeys]) {
        NSInteger current = self.eventListeners[key].intValue;
        if (current > removeCount) {
            self.eventListeners[key] = @(current - removeCount);
        } else {
            [self.eventListeners removeObjectForKey:key];
        }
    }
}

RCT_EXPORT_METHOD(getRecognitionLanguage:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    NSLocale *locale = [NSLocale currentLocale];
    NSString *language = [locale objectForKey:NSLocaleLanguageCode];
    NSString *country = [locale objectForKey:NSLocaleCountryCode];

    resolve(country ? [NSString stringWithFormat:@"%@-%@", language, country] : language);
}

RCT_EXPORT_METHOD(setRecognitionLanguage:(NSString *)languageTag
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    @try {
        NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:languageTag];
        _speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:locale];
        if (!_speechRecognizer || !_speechRecognizer.isAvailable) {
            reject(@"LANGUAGE_ERROR", @"Not available", nil);
            return;
        }
        resolve(@YES);
    } @catch (NSException *e) {
        reject(@"LANGUAGE_ERROR", e.reason, nil);
    }
}

RCT_EXPORT_METHOD(isRecognitionAvailable:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    NSLocale *locale = [NSLocale currentLocale];
    SFSpeechRecognizer *recognizer = [[SFSpeechRecognizer alloc] initWithLocale:locale];
    resolve(@(recognizer && recognizer.isAvailable));
}

RCT_EXPORT_METHOD(getSupportedLanguages:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    NSArray *identifiers = @[
        @"en-US", @"en-GB", @"fr-FR", @"de-DE", @"it-IT", @"es-ES",
        @"ja-JP", @"ko-KR", @"zh-CN", @"ru-RU", @"pt-BR", @"nl-NL",
        @"hi-IN", @"ar-SA"
    ];
    NSMutableArray *supported = [NSMutableArray new];

    for (NSString *id in identifiers) {
        NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:id];
        SFSpeechRecognizer *recognizer = [[SFSpeechRecognizer alloc] initWithLocale:locale];
        if (recognizer && recognizer.isAvailable) {
            [supported addObject:id];
        }
    }

    resolve(supported);
}

@end
