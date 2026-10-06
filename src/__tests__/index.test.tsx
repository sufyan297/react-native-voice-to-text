import type { Spec } from '../NativeVoiceToText';

// The real NativeEventEmitter uses Flow syntax that the project's
// builder-bob babel preset cannot parse under jest, so stand in a faithful
// mock: same iOS invariant, same listener-count forwarding to the module.
jest.mock('react-native/Libraries/EventEmitter/NativeEventEmitter', () => {
  class NativeEventEmitter {
    _nativeModule: any;

    constructor(nativeModule: any) {
      if (jest.requireActual('react-native').Platform.OS === 'ios') {
        if (nativeModule == null) {
          throw new Error(
            '`new NativeEventEmitter()` requires a non-null argument.'
          );
        }
      }
      this._nativeModule = nativeModule;
    }

    addListener(eventType: string) {
      this._nativeModule?.addListener?.(eventType);
      return {
        remove: () => {
          this._nativeModule?.removeListeners?.(1);
        },
      };
    }

    removeAllListeners(_eventType: string) {
      this._nativeModule?.removeListeners?.(0);
    }

    listenerCount() {
      return 0;
    }
  }

  return { __esModule: true, default: NativeEventEmitter };
});

const LINKING_ERROR_MATCH = /native module "VoiceToText" is not available/;

type VoiceToTextModule = typeof import('../index');

function loadVoiceToText(nativeModule?: Partial<Spec>): VoiceToTextModule {
  let voiceToTextModule!: VoiceToTextModule;
  jest.isolateModules(() => {
    const { NativeModules } = require('react-native');
    NativeModules.VoiceToText = nativeModule;
    voiceToTextModule = require('../index');
  });
  return voiceToTextModule;
}

function makeNativeModule(): Spec & Record<string, jest.Mock> {
  return {
    startListening: jest.fn(() => Promise.resolve('started')),
    stopListening: jest.fn(() => Promise.resolve('stopped')),
    destroy: jest.fn(() => Promise.resolve('destroyed')),
    addListener: jest.fn(),
    removeListeners: jest.fn(),
    getRecognitionLanguage: jest.fn(() => Promise.resolve('en-US')),
    setRecognitionLanguage: jest.fn(() => Promise.resolve(true)),
    isRecognitionAvailable: jest.fn(() => Promise.resolve(true)),
    getSupportedLanguages: jest.fn(() => Promise.resolve(['en-US'])),
  } as unknown as Spec & Record<string, jest.Mock>;
}

describe('@ascendtis/react-native-voice-to-text', () => {
  it('can be imported without the native module registered', () => {
    expect(() => loadVoiceToText()).not.toThrow();
  });

  it('throws a descriptive error when the native module is missing', () => {
    const voiceToText = loadVoiceToText();

    expect(() => voiceToText.startListening()).toThrow(LINKING_ERROR_MATCH);
    expect(() => voiceToText.stopListening()).toThrow(LINKING_ERROR_MATCH);
    expect(() => voiceToText.destroy()).toThrow(LINKING_ERROR_MATCH);
    expect(() => voiceToText.getRecognitionLanguage()).toThrow(
      LINKING_ERROR_MATCH
    );
    expect(() => voiceToText.setRecognitionLanguage('en-US')).toThrow(
      LINKING_ERROR_MATCH
    );
    expect(() => voiceToText.isRecognitionAvailable()).toThrow(
      LINKING_ERROR_MATCH
    );
    expect(() => voiceToText.getSupportedLanguages()).toThrow(
      LINKING_ERROR_MATCH
    );
    expect(() => voiceToText.addEventListener('onSpeech', () => {})).toThrow(
      LINKING_ERROR_MATCH
    );
    expect(() => voiceToText.removeAllListeners('onSpeech')).toThrow(
      LINKING_ERROR_MATCH
    );
  });

  it('delegates calls to the native module when registered', async () => {
    const nativeModule = makeNativeModule();
    const voiceToText = loadVoiceToText(nativeModule);

    await expect(voiceToText.startListening()).resolves.toBe('started');
    await expect(voiceToText.stopListening()).resolves.toBe('stopped');
    await expect(voiceToText.destroy()).resolves.toBe('destroyed');
    await expect(voiceToText.getRecognitionLanguage()).resolves.toBe('en-US');
    await expect(voiceToText.setRecognitionLanguage('en-US')).resolves.toBe(
      true
    );
    await expect(voiceToText.isRecognitionAvailable()).resolves.toBe(true);
    await expect(voiceToText.getSupportedLanguages()).resolves.toEqual([
      'en-US',
    ]);
    expect(nativeModule.startListening).toHaveBeenCalled();
  });

  it('creates the event emitter and subscribes when the native module is registered', () => {
    const nativeModule = makeNativeModule();
    const voiceToText = loadVoiceToText(nativeModule);

    const subscription = voiceToText.addEventListener('onSpeech', () => {});
    expect(typeof subscription.remove).toBe('function');

    voiceToText.removeAllListeners('onSpeech');
    expect(nativeModule.addListener).toHaveBeenCalledWith('onSpeech');
    expect(nativeModule.removeListeners).toHaveBeenCalled();
  });
});
