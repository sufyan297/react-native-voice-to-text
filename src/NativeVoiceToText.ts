import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  startListening(): Promise<string>;
  stopListening(): Promise<string>;
  destroy(): Promise<string>;
  addListener(eventName: string): void;
  removeListeners(count: number): void;

  // New methods
  getRecognitionLanguage(): Promise<string>;
  setRecognitionLanguage(languageTag: string): Promise<boolean>;
  isRecognitionAvailable(): Promise<boolean>;
  getSupportedLanguages(): Promise<string[]>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('VoiceToText');
