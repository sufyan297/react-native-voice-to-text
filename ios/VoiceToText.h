#import <Foundation/Foundation.h>
#import <Speech/Speech.h>
#import "generated/RNVoiceToTextSpec/RNVoiceToTextSpec.h"
#import <React/RCTEventEmitter.h>
#import <React/RCTBridgeModule.h>

@interface VoiceToText : RCTEventEmitter <RCTBridgeModule>

@property (nonatomic, strong) SFSpeechRecognizer *speechRecognizer;
@property (nonatomic, strong) SFSpeechAudioBufferRecognitionRequest *recognitionRequest;
@property (nonatomic, strong) SFSpeechRecognitionTask *recognitionTask;
@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic) BOOL isListening;

@end
