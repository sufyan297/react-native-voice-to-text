# @ascendtis/react-native-voice-to-text

[![npm version](https://img.shields.io/npm/v/@ascendtis/react-native-voice-to-text)](https://www.npmjs.com/package/@ascendtis/react-native-voice-to-text)
[![npm downloads](https://img.shields.io/npm/dw/@ascendtis/react-native-voice-to-text)](https://www.npmjs.com/package/@ascendtis/react-native-voice-to-text)
[![license](https://img.shields.io/npm/l/@ascendtis/react-native-voice-to-text)](https://www.npmjs.com/package/@ascendtis/react-native-voice-to-text)

Convert voice to text in real time using the native speech recognition capabilities of iOS and Android.

This package is a maintained carry-forward of the unmaintained [`react-native-voice-to-text`](https://www.npmjs.com/package/react-native-voice-to-text), rebuilt with full iOS support, New Architecture (TurboModule) compatibility, and ongoing maintenance.

## Features

- Native speech recognition on both iOS (`SFSpeechRecognizer`) and Android (`SpeechRecognizer`)
- Real-time partial results as the user speaks
- Final transcription with confidence scores (Android)
- Volume level detection (Android)
- Multi-language support: query, list, and switch the recognition language
- New Architecture ready (TurboModule with codegen)
- Written in TypeScript with full type definitions

## Requirements

| Platform | Minimum |
|----------|---------|
| iOS | 15.1 |
| Android | API 24 (Android 7.0) |
| React Native | 0.78+ (built and tested against 0.78.1) |

> **Note:** This package contains native code, so it does not work in **Expo Go**. Use a [development build](https://docs.expo.dev/develop/development-builds/introduction/) or a bare React Native project.

## Installation

```sh
npm install @ascendtis/react-native-voice-to-text
```

or

```sh
yarn add @ascendtis/react-native-voice-to-text
```

The package is auto-linked on both platforms. On iOS, install the CocoaPods dependency:

```sh
cd ios && pod install
```

Then rebuild your app so the native module is registered.

## Permissions

### iOS

Add the following keys to your `Info.plist`:

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

For Android 6.0+ (API 23), you also need to request the permission at runtime:

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

## Usage

```js
import React, { useEffect, useState } from 'react';
import { Button, Text, View } from 'react-native';
import {
  addEventListener,
  destroy,
  startListening,
  stopListening,
} from '@ascendtis/react-native-voice-to-text';

export default function SpeechToText() {
  const [result, setResult] = useState('');
  const [isListening, setIsListening] = useState(false);

  useEffect(() => {
    const subscriptions = [
      addEventListener('onSpeechStart', () => setIsListening(true)),
      addEventListener('onSpeechEnd', () => setIsListening(false)),
      addEventListener('onSpeechResults', (event) => {
        setResult(event.value ?? '');
      }),
      addEventListener('onSpeechError', (event) => {
        console.error('Speech recognition error:', event.message);
        setIsListening(false);
      }),
    ];

    return () => {
      subscriptions.forEach((subscription) => subscription.remove());
      destroy();
    };
  }, []);

  const toggleListening = async () => {
    try {
      if (isListening) {
        await stopListening();
      } else {
        setResult('');
        await startListening();
      }
    } catch (error) {
      console.error(error);
    }
  };

  return (
    <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
      <Text>{result || 'Say something...'}</Text>
      <Button
        title={isListening ? 'Stop Listening' : 'Start Listening'}
        onPress={toggleListening}
      />
    </View>
  );
}
```

### Switching the recognition language

```js
import {
  getSupportedLanguages,
  setRecognitionLanguage,
} from '@ascendtis/react-native-voice-to-text';

const languages = await getSupportedLanguages(); // e.g. ['en-US', 'en-GB', 'fr-FR', ...]
const success = await setRecognitionLanguage('en-GB');
```

## API Reference

All functions are named exports of the package. If the native module is not available (e.g. the app was not rebuilt after installation, or `pod install` was skipped), every function throws a descriptive error explaining how to fix the setup.

### Methods

| Method | Description | Return Type |
|--------|-------------|-------------|
| `startListening()` | Start speech recognition | `Promise<string>` |
| `stopListening()` | Stop speech recognition | `Promise<string>` |
| `destroy()` | Clean up speech recognition resources | `Promise<string>` |
| `getRecognitionLanguage()` | Get current recognition language | `Promise<string>` |
| `setRecognitionLanguage(languageTag)` | Set recognition language (e.g. `'en-US'`) | `Promise<boolean>` |
| `isRecognitionAvailable()` | Check if speech recognition is available on the device | `Promise<boolean>` |
| `getSupportedLanguages()` | Get list of supported language codes | `Promise<string[]>` |
| `addEventListener(eventName, handler)` | Subscribe to an event; call `.remove()` on the returned subscription to unsubscribe | `EventSubscription` |
| `removeAllListeners(eventName)` | Remove all listeners for an event | `void` |

### Events

Subscribe with `addEventListener('onSpeechResults', handler)` etc. Event names are plain strings.

| Event | Platforms | Payload |
|-------|-----------|---------|
| `onSpeechStart` | iOS, Android | — (recognition started) |
| `onSpeechBegin` | Android | — (user began speaking) |
| `onSpeechEnd` | iOS, Android | `{ message?: string }` |
| `onSpeechError` | iOS, Android | `{ code: number, message: string }` — `code` is platform-specific (negative values on iOS, `SpeechRecognizer.ERROR_*` values on Android) |
| `onSpeechResults` | iOS, Android | `{ value: string, results?: { transcriptions: Array<{ text: string, confidence: number }> } }` — `results` is Android-only |
| `onSpeechPartialResults` | iOS, Android | `{ value: string, results?: { transcriptions: Array<{ text: string }> } }` — `results` is Android-only |
| `onSpeechVolumeChanged` | Android | `{ value: number }` (RMS loudness in dB) |
| `onSpeechAudioBuffer` | Android | `{ buffer: string }` (Base64-encoded raw audio) |
| `onSpeechEvent` | Android | `{ eventType: number, ... }` (service-specific events) |

## Troubleshooting

**`The native module "VoiceToText" is not available`**
The native side was not registered. Make sure you ran `pod install` on iOS and rebuilt the app after installing the package. The module is not available in Expo Go — use a development build. Since v0.4.0 this surfaces as a descriptive error at call time instead of crashing the app on import.

**Speech recognition does not work on the iOS Simulator**
Simulator support for `SFSpeechRecognizer` varies across Xcode/simulator versions. Always verify speech features on a physical device.

**Android build fails with `Cannot add extension with name 'kotlin'`**
Caused by Android Gradle Plugin 9 registering built-in Kotlin support. Fixed in v0.4.1 — upgrade to `@ascendtis/react-native-voice-to-text@0.4.1` or later.

**Android runtime errors (`should be used only from the application main thread`, `Cannot convert argument` / `ArrayList`)**
Both are fixed in the 0.3.x releases. Upgrade if you are on an older version.

## Contributing

Issues and pull requests are welcome! See the [issue tracker](https://github.com/sufyan297/react-native-voice-to-text/issues).

```sh
corepack yarn            # install dependencies (Yarn 3 via corepack)
corepack yarn prepare    # build lib/ with react-native-builder-bob
corepack yarn test       # run the Jest test suite
corepack yarn typecheck  # TypeScript
corepack yarn lint       # ESLint
corepack yarn example    # run the example app (react-native run-android / run-ios)
```

If Yarn reports the lockfile is out of date, run `corepack yarn install` once first.

## License

MIT

## Credits

This package is a continued fork of [`react-native-voice-to-text`](https://www.npmjs.com/package/react-native-voice-to-text) by [Abhaya Kumar Sahoo](https://github.com/abhaya-kumar-sahoo) (Android-only, no longer maintained). Thanks for the great starting point.

Scaffolded with [create-react-native-library](https://github.com/callstack/create-react-native-library).
