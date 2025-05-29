import { NativeModules, NativeEventEmitter } from 'react-native';

const { VoiceToText } = NativeModules;
const emitter = new NativeEventEmitter(VoiceToText);

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
  return emitter.addListener(eventName, handler);
}

export function removeAllListeners(eventName: string) {
  emitter.removeAllListeners(eventName);
}
