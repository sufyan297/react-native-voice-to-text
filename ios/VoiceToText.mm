#import "VoiceToText.h"
#import <AVFoundation/AVFoundation.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTLog.h>

@implementation VoiceToText {
    bool hasListeners;
    NSMutableDictionary<NSString *, NSNumber *> *eventListeners;
}

RCT_EXPORT_MODULE()

+ (BOOL)requiresMainQueueSetup {
    return YES;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isListening = NO;
        _audioEngine = [[AVAudioEngine alloc] init];
        eventListeners = [NSMutableDictionary new];
        
        // Request permission as early as possible
        [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
            dispatch_async(dispatch_get_main_queue(), ^{
                switch (status) {
                    case SFSpeechRecognizerAuthorizationStatusAuthorized:
                        break;
                    case SFSpeechRecognizerAuthorizationStatusDenied:
                        [self sendEventWithName:@"onSpeechError" body:@{@"message": @"Permission denied for speech recognition", @"code": @(-1)}];
                        break;
                    case SFSpeechRecognizerAuthorizationStatusRestricted:
                        [self sendEventWithName:@"onSpeechError" body:@{@"message": @"Speech recognition restricted on this device", @"code": @(-2)}];
                        break;
                    case SFSpeechRecognizerAuthorizationStatusNotDetermined:
                        [self sendEventWithName:@"onSpeechError" body:@{@"message": @"Speech recognition not authorized", @"code": @(-3)}];
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
        RCTLogError(@"Error setting up audio session: %@", error);
        [self sendEventWithName:@"onSpeechError" body:@{
            @"message": [NSString stringWithFormat:@"Error setting up audio session: %@", error.localizedDescription],
            @"code": @(-100)
        }];
        return;
    }
    [audioSession setMode:AVAudioSessionModeMeasurement error:&error];
    if (error) {
        RCTLogError(@"Error setting audio session mode: %@", error);
        [self sendEventWithName:@"onSpeechError" body:@{
            @"message": [NSString stringWithFormat:@"Error setting audio session mode: %@", error.localizedDescription],
            @"code": @(-101)
        }];
        return;
    }
    [audioSession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
    if (error) {
        RCTLogError(@"Error activating audio session: %@", error);
        [self sendEventWithName:@"onSpeechError" body:@{
            @"message": [NSString stringWithFormat:@"Error activating audio session: %@", error.localizedDescription],
            @"code": @(-102)
        }];
        return;
    }
}

- (NSString *)startListening:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject {
    if (_isListening) {
        reject(@"ALREADY_LISTENING", @"Speech recognition already in progress", nil);
        return nil;
    }
    
    // Initialize speech recognizer with the device locale
    NSLocale *locale = [NSLocale currentLocale];
    _speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:locale];
    
    if (!_speechRecognizer) {
        reject(@"NOT_AVAILABLE", @"Speech recognition not available for the current locale", nil);
        return nil;
    }
    
    if (_speechRecognizer.isAvailable == NO) {
        reject(@"NOT_AVAILABLE", @"Speech recognition not currently available", nil);
        return nil;
    }
    
    // Check and request authorization status
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            switch (status) {
                case SFSpeechRecognizerAuthorizationStatusAuthorized: {
                    NSError *error;
                    // Setup audio session
                    [self setupAudioSession];
                    
                    // Stop existing task if there is one
                    if (self.recognitionTask) {
                        [self.recognitionTask cancel];
                        self.recognitionTask = nil;
                    }
                    
                    // Create and configure the speech recognition request
                    self.recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
                    if (!self.recognitionRequest) {
                        reject(@"INIT_ERROR", @"Unable to create a speech recognition request", nil);
                        return;
                    }
                    
                    self.recognitionRequest.shouldReportPartialResults = YES;
                    self.recognitionRequest.taskHint = SFSpeechRecognitionTaskHintDictation;
                    
                    // Start recognition
                    AVAudioInputNode *inputNode = self.audioEngine.inputNode;
                    
                    self.recognitionTask = [self.speechRecognizer recognitionTaskWithRequest:self.recognitionRequest resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
                        BOOL isFinal = NO;
                        
                        if (result) {
                            isFinal = result.isFinal;
                            
                            NSMutableArray *transcriptions = [NSMutableArray new];
                            
                            for (SFTranscription *transcription in result.transcriptions) {
                                NSMutableDictionary *transcriptionDict = [NSMutableDictionary new];
                                [transcriptionDict setObject:transcription.formattedString forKey:@"text"];
                                
                                // Include segment data if available
                                if (transcription.segments.count > 0) {
                                    NSMutableArray *segments = [NSMutableArray new];
                                    for (SFTranscriptionSegment *segment in transcription.segments) {
                                        NSMutableDictionary *segmentDict = [NSMutableDictionary new];
                                        [segmentDict setObject:segment.substring forKey:@"text"];
                                        [segmentDict setObject:@(segment.confidence) forKey:@"confidence"];
                                        [segments addObject:segmentDict];
                                    }
                                    [transcriptionDict setObject:segments forKey:@"segments"];
                                }
                                
                                [transcriptions addObject:transcriptionDict];
                            }
                            
                            NSMutableDictionary *resultDict = [NSMutableDictionary new];
                            [resultDict setObject:transcriptions forKey:@"transcriptions"];
                            
                            NSMutableDictionary *params = [NSMutableDictionary new];
                            [params setObject:resultDict forKey:@"results"];
                            [params setObject:result.bestTranscription.formattedString forKey:@"value"];
                            
                            if (isFinal) {
                                [self sendEventWithName:@"onSpeechResults" body:params];
                            } else {
                                [self sendEventWithName:@"onSpeechPartialResults" body:params];
                            }
                        }
                        
                        if (error || isFinal) {
                            [self.audioEngine stop];
                            [inputNode removeTapOnBus:0];
                            
                            self.recognitionRequest = nil;
                            self.recognitionTask = nil;
                            self.isListening = NO;
                            
                            if (error) {
                                RCTLogError(@"Speech recognition error: %@", error);
                                [self sendEventWithName:@"onSpeechError" body:@{
                                    @"message": [NSString stringWithFormat:@"Recognition error: %@", error.localizedDescription],
                                    @"code": @(error.code)
                                }];
                            }
                            
                            if (isFinal) {
                                [self sendEventWithName:@"onSpeechEnd" body:nil];
                            }
                        }
                    }];
                    
                    // Configure the microphone input
                    [inputNode installTapOnBus:0 bufferSize:1024 format:[inputNode outputFormatForBus:0] block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
                        // If requested by JS side, send raw audio buffer data
                        if ([eventListeners[@"onSpeechAudioBuffer"] intValue] > 0) {
                            // Convert PCM buffer to data that can be sent to JS
                            NSData *audioData = [NSData dataWithBytes:buffer.floatChannelData[0]
                                                               length:buffer.frameLength * buffer.format.streamDescription->mBytesPerFrame];
                            // Base64 encode for safe transport
                            NSString *base64Audio = [audioData base64EncodedStringWithOptions:0];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self sendEventWithName:@"onSpeechAudioBuffer" body:@{@"buffer": base64Audio}];
                            });
                        }
                        
                        // Calculate and send volume updates if requested
                        if ([eventListeners[@"onSpeechVolumeChanged"] intValue] > 0) {
                            float *channelData = buffer.floatChannelData[0];
                            float sum = 0.0f;
                            for (UInt32 i = 0; i < buffer.frameLength; i++) {
                                sum += channelData[i] * channelData[i];
                            }
                            float rms = sqrt(sum / buffer.frameLength);
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self sendEventWithName:@"onSpeechVolumeChanged" body:@{@"value": @(rms)}];
                            });
                        }
                        
                        [self.recognitionRequest appendAudioPCMBuffer:buffer];
                    }];
                    
                    // Notify that speech has started
                    [self sendEventWithName:@"onSpeechBegin" body:nil];
                    
                    // Start the audio engine
                    [self.audioEngine prepare];
                    NSError *audioError = nil;
                    if (![self.audioEngine startAndReturnError:&audioError]) {
                        RCTLogError(@"Could not start audio engine: %@", audioError);
                        reject(@"AUDIO_ERROR", [NSString stringWithFormat:@"Could not start audio engine: %@", audioError.localizedDescription], audioError);
                        return;
                    }
                    
                    self.isListening = YES;
                    [self sendEventWithName:@"onSpeechStart" body:nil];
                    resolve(@"Started listening");
                    break;
                }
                    
                case SFSpeechRecognizerAuthorizationStatusDenied:
                    reject(@"PERMISSION_DENIED", @"Speech recognition permission denied", nil);
                    break;
                    
                case SFSpeechRecognizerAuthorizationStatusRestricted:
                    reject(@"PERMISSION_RESTRICTED", @"Speech recognition restricted on this device", nil);
                    break;
                    
                case SFSpeechRecognizerAuthorizationStatusNotDetermined:
                    reject(@"PERMISSION_NOT_DETERMINED", @"Speech recognition permission not determined", nil);
                    break;
            }
        });
    }];
    
    return nil;
}

- (NSString *)stopListening:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject {
    if (!_isListening) {
        reject(@"NOT_LISTENING", @"Speech recognition not in progress", nil);
        return nil;
    }
    
    [_audioEngine stop];
    [_audioEngine.inputNode removeTapOnBus:0];
    _isListening = NO;
    
    [_recognitionRequest endAudio];
    [_recognitionTask cancel];
    
    _recognitionRequest = nil;
    _recognitionTask = nil;
    
    [self sendEventWithName:@"onSpeechEnd" body:nil];
    resolve(@"Stopped listening");
    return nil;
}

- (NSString *)destroy:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject {
    [_audioEngine stop];
    [_audioEngine.inputNode removeTapOnBus:0];
    
    _recognitionRequest = nil;
    _recognitionTask = nil;
    _speechRecognizer = nil;
    _isListening = NO;
    
    // Clear event listeners
    [eventListeners removeAllObjects];
    
    resolve(@"Speech recognizer destroyed");
    return nil;
}

- (void)addListener:(NSString *)eventName {
    NSNumber *count = eventListeners[eventName];
    if (count) {
        eventListeners[eventName] = @([count intValue] + 1);
    } else {
        eventListeners[eventName] = @1;
    }
    RCTLogInfo(@"Added listener for %@, total: %@", eventName, eventListeners[eventName]);
}

- (void)removeListeners:(double)count {
    NSInteger countInt = (NSInteger)count;
    NSArray *keys = [eventListeners allKeys];
    
    for (NSString *key in keys) {
        NSInteger currentCount = [eventListeners[key] intValue];
        NSInteger newCount = MAX(0, currentCount - countInt);
        
        if (newCount > 0) {
            eventListeners[key] = @(newCount);
        } else {
            [eventListeners removeObjectForKey:key];
        }
    }
    
    RCTLogInfo(@"Removed %ld listeners, remaining events: %@", (long)countInt, [eventListeners allKeys]);
}

// Get the current recognition language
RCT_EXPORT_METHOD(getRecognitionLanguage:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    NSLocale *locale = [NSLocale currentLocale];
    NSString *languageCode = [locale objectForKey:NSLocaleLanguageCode];
    NSString *countryCode = [locale objectForKey:NSLocaleCountryCode];
    
    NSString *languageTag;
    if (countryCode) {
        languageTag = [NSString stringWithFormat:@"%@-%@", languageCode, countryCode];
    } else {
        languageTag = languageCode;
    }
    
    resolve(languageTag);
}

// Set the recognition language
RCT_EXPORT_METHOD(setRecognitionLanguage:(NSString *)languageTag
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    @try {
        NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:languageTag];
        _speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:locale];
        
        if (!_speechRecognizer || !_speechRecognizer.isAvailable) {
            reject(@"LANGUAGE_ERROR", @"Speech recognition not available for the specified language", nil);
            return;
        }
        
        resolve(@YES);
    } @catch (NSException *exception) {
        reject(@"LANGUAGE_ERROR", [NSString stringWithFormat:@"Error setting language: %@", exception.reason], nil);
    }
}

// Check if speech recognition is available
RCT_EXPORT_METHOD(isRecognitionAvailable:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    NSLocale *locale = [NSLocale currentLocale];
    SFSpeechRecognizer *recognizer = [[SFSpeechRecognizer alloc] initWithLocale:locale];
    
    BOOL isAvailable = recognizer && recognizer.isAvailable;
    resolve(@(isAvailable));
}

// Get supported languages for speech recognition
RCT_EXPORT_METHOD(getSupportedLanguages:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {
    NSMutableArray *supportedLocales = [NSMutableArray new];
    
    // Common languages supported by iOS speech recognition
    NSArray *localeIdentifiers = @[
        @"en-US", @"en-GB", @"fr-FR", @"de-DE", @"it-IT", @"es-ES",
        @"ja-JP", @"ko-KR", @"zh-CN", @"ru-RU", @"pt-BR", @"nl-NL",
        @"hi-IN", @"ar-SA"
    ];
    
    // Check which ones are actually available on this device
    for (NSString *identifier in localeIdentifiers) {
        NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:identifier];
        SFSpeechRecognizer *recognizer = [[SFSpeechRecognizer alloc] initWithLocale:locale];
        
        if (recognizer && recognizer.isAvailable) {
            [supportedLocales addObject:identifier];
        }
    }
    
    resolve(supportedLocales);
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeVoiceToTextSpecJSI>(params);
}

@end
