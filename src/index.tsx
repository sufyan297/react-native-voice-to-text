import { NativeModules, NativeEventEmitter } from 'react-native';
import type { Spec } from './NativeVoiceToText';

const LINKING_ERROR =
  'The native module "VoiceToText" is not available. ' +
  "Make sure you rebuilt the app after installing '@ascendtis/react-native-voice-to-text', " +
  'ran `pod install` on iOS, and are not running in Expo Go.';

const { VoiceToText } = NativeModules;

function getModule(): Spec {
  if (VoiceToText == null) {
    throw new Error(LINKING_ERROR);
  }
  return VoiceToText as Spec;
}

let emitter: NativeEventEmitter | null = null;

function getEmitter(): NativeEventEmitter {
  if (emitter == null) {
    emitter = new NativeEventEmitter(getModule());
  }
  return emitter;
}

export function startListening(): Promise<string> {
  return getModule().startListening();
}
export function stopListening(): Promise<string> {
  return getModule().stopListening();
}

export function destroy(): Promise<string> {
  return getModule().destroy();
}

export function getRecognitionLanguage(): Promise<string> {
  return getModule().getRecognitionLanguage();
}

export function setRecognitionLanguage(languageTag: string): Promise<boolean> {
  return getModule().setRecognitionLanguage(languageTag);
}

export function isRecognitionAvailable(): Promise<boolean> {
  return getModule().isRecognitionAvailable();
}

export function getSupportedLanguages(): Promise<string[]> {
  return getModule().getSupportedLanguages();
}

export function addEventListener(
  eventName: string,
  handler: (event: any) => void
) {
  return getEmitter().addListener(eventName, handler);
}

export function removeAllListeners(eventName: string) {
  getEmitter().removeAllListeners(eventName);
}
