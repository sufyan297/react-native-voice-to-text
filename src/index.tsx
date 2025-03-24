import { NativeEventEmitter } from 'react-native';
import VoiceToText from './NativeVoiceToText';

export const VoiceToTextEvents = {
  START: 'onSpeechStart',
  BEGIN: 'onSpeechBegin',
  END: 'onSpeechEnd',
  ERROR: 'onSpeechError',
  RESULTS: 'onSpeechResults',
  PARTIAL_RESULTS: 'onSpeechPartialResults',
  VOLUME_CHANGED: 'onSpeechVolumeChanged',
  AUDIO_BUFFER: 'onSpeechAudioBuffer',
  EVENT: 'onSpeechEvent',
};

const voiceToTextEmitter = new NativeEventEmitter(VoiceToText as any);

export function startListening(): Promise<string> {
  return VoiceToText.startListening();
}

export function stopListening(): Promise<string> {
  return VoiceToText.stopListening();
}

export function destroy(): Promise<string> {
  return VoiceToText.destroy();
}

export function getRecognitionLanguage(): Promise<string> {
  return VoiceToText.getRecognitionLanguage();
}

export function setRecognitionLanguage(languageTag: string): Promise<boolean> {
  return VoiceToText.setRecognitionLanguage(languageTag);
}

export function isRecognitionAvailable(): Promise<boolean> {
  return VoiceToText.isRecognitionAvailable();
}

export function getSupportedLanguages(): Promise<string[]> {
  return VoiceToText.getSupportedLanguages();
}

export function addEventListener(
  eventName: string,
  handler: (event: any) => void
) {
  return voiceToTextEmitter.addListener(eventName, handler);
}

export function removeAllListeners(eventName: string) {
  voiceToTextEmitter.removeAllListeners(eventName);
}

export default {
  startListening,
  stopListening,
  destroy,
  getRecognitionLanguage,
  setRecognitionLanguage,
  isRecognitionAvailable,
  getSupportedLanguages,
  addEventListener,
  removeAllListeners,
  ...VoiceToTextEvents,
};
