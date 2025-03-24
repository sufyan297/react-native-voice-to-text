# react-native-voice-to-text

Convert voice to text in React Native using native speech recognition capabilities on both iOS and Android.

## Features

- Utilize the device's native speech recognition API
- Support for multiple languages
- Real-time partial results as the user speaks
- Volume level detection
- Detailed transcription results with confidence scores
- Cross-platform compatibility (iOS and Android)
- Written in TypeScript with full type definitions

## Installation

```sh
npm install react-native-voice-to-text
```

## Permissions

### iOS
You need to add the following permissions to your `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to your microphone for speech recognition</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>This app needs access to speech recognition to convert your voice to text</string>
```

### Android
Add the following permission to your `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

For Android 6.0+ (API level 23), you also need to request the permission at runtime:

```js
import { Platform, PermissionsAndroid } from 'react-native';

// Request microphone permission
async function requestMicrophonePermission() {
  if (Platform.OS !== 'android') return true;

  try {
    const granted = await PermissionsAndroid.request(
      PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
      {
        title: 'Microphone Permission',
        message: 'This app needs access to your microphone for speech recognition',
        buttonPositive: 'OK',
      }
    );
    return granted === PermissionsAndroid.RESULTS.GRANTED;
  } catch (err) {
    console.warn(err);
    return false;
  }
}
```

## API Reference

### Methods

| Method | Description | Return Type |
|--------|-------------|-------------|
| `startListening()` | Start speech recognition | `Promise<string>` |
| `stopListening()` | Stop speech recognition | `Promise<string>` |
| `destroy()` | Clean up speech recognition resources | `Promise<string>` |
| `getRecognitionLanguage()` | Get current recognition language | `Promise<string>` |
| `setRecognitionLanguage(languageTag)` | Set recognition language (e.g., 'en-US') | `Promise<boolean>` |
| `isRecognitionAvailable()` | Check if speech recognition is available on device | `Promise<boolean>` |
| `getSupportedLanguages()` | Get list of supported language codes | `Promise<string[]>` |
| `addEventListener(eventName, callback)` | Add event listener | `EmitterSubscription` |
| `removeAllListeners(eventName)` | Remove all listeners for event | `void` |

### Events

| Event | Description | Data |
|-------|-------------|------|
| `VoiceToTextEvents.START` | Speech recognition started | `null` |
| `VoiceToTextEvents.BEGIN` | User began speaking | `null` |
| `VoiceToTextEvents.END` | Speech recognition ended | `null` |
| `VoiceToTextEvents.ERROR` | Error occurred | `{ code: number, message: string }` |
| `VoiceToTextEvents.RESULTS` | Final results obtained | `{ value: string, results: { transcriptions: Array<{ text: string, confidence: number }> } }` |
| `VoiceToTextEvents.PARTIAL_RESULTS` | Partial results as user speaks | `{ value: string, results: { transcriptions: Array<{ text: string }> } }` |
| `VoiceToTextEvents.VOLUME_CHANGED` | Volume level changed | `{ value: number }` |
| `VoiceToTextEvents.AUDIO_BUFFER` | Raw audio buffer available | `{ buffer: string }` (Base64 encoded) |

## Basic Usage

```js
import React, { useEffect, useState } from 'react';
import { View, Button, Text } from 'react-native';
import VoiceToText, { VoiceToTextEvents } from 'react-native-voice-to-text';

export default function SpeechRecognitionExample() {
  const [results, setResults] = useState('');
  const [isListening, setIsListening] = useState(false);
  
  useEffect(() => {
    // Set up event listeners
    const resultsListener = VoiceToText.addEventListener(
      VoiceToTextEvents.RESULTS,
      (event) => {
        setResults(event.value);
      }
    );
    
    const startListener = VoiceToText.addEventListener(
      VoiceToTextEvents.START,
      () => setIsListening(true)
    );
    
    const endListener = VoiceToText.addEventListener(
      VoiceToTextEvents.END,
      () => setIsListening(false)
    );
    
    // Clean up
    return () => {
      VoiceToText.destroy();
      resultsListener.remove();
      startListener.remove();
      endListener.remove();
    };
  }, []);
  
  const toggleListening = async () => {
    try {
      if (isListening) {
        await VoiceToText.stopListening();
      } else {
        await VoiceToText.startListening();
      }
    } catch (error) {
      console.error(error);
    }
  };
  
  return (
    <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
      <Text>{results || 'Say something...'}</Text>
      <Button
        title={isListening ? 'Stop' : 'Start'}
        onPress={toggleListening}
      />
    </View>
  );
}
```

## Known Issues and Fixes

### Android
- **Thread Error**: SpeechRecognizer operations must run on the main thread in Android. This is handled internally in the latest version.
- **Type Conversion**: ArrayList type conversion for language lists is now properly handled.

### iOS
- Speech recognition requires user permission prompt which is handled via Info.plist settings.

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
