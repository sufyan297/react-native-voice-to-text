import { useEffect, useState } from 'react';
import {
  Text,
  View,
  StyleSheet,
  Button,
  ActivityIndicator,
  Alert,
  Platform,
  PermissionsAndroid,
  ScrollView,
  TouchableOpacity,
} from 'react-native';
import VoiceToText, { VoiceToTextEvents } from 'react-native-voice-to-text';

export default function App() {
  const [results, setResults] = useState('');
  const [isListening, setIsListening] = useState(false);
  const [isAvailable, setIsAvailable] = useState(false);
  const [currentLanguage, setCurrentLanguage] = useState('');
  const [permissionGranted, setPermissionGranted] = useState(false);
  const [supportedLanguages, setSupportedLanguages] = useState<string[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  // Request microphone permission
  const requestMicrophonePermission = async () => {
    try {
      if (Platform.OS === 'android') {
        const granted = await PermissionsAndroid.request(
          PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
          {
            title: 'Microphone Permission',
            message:
              'This app needs access to your microphone for speech recognition',
            buttonNeutral: 'Ask Me Later',
            buttonNegative: 'Cancel',
            buttonPositive: 'OK',
          }
        );

        if (granted === PermissionsAndroid.RESULTS.GRANTED) {
          setPermissionGranted(true);
          return true;
        } else {
          Alert.alert(
            'Permission Required',
            'Microphone permission is required for speech recognition'
          );
          return false;
        }
      } else {
        // For iOS, permissions are handled through Info.plist
        // We just assume it's granted for this example since iOS will prompt automatically
        setPermissionGranted(true);
        return true;
      }
    } catch (error) {
      console.error('Error requesting microphone permission:', error);
      return false;
    }
  };

  useEffect(() => {
    // Check permissions and speech recognition availability
    const initialize = async () => {
      // First request permission
      const hasPermission = await requestMicrophonePermission();
      if (!hasPermission) return;

      // Then check if speech recognition is available
      try {
        const available = await VoiceToText.isRecognitionAvailable();
        setIsAvailable(available);

        if (available) {
          const language = await VoiceToText.getRecognitionLanguage();
          setCurrentLanguage(language);

          // Get supported languages with error handling
          try {
            const languages = await VoiceToText.getSupportedLanguages();
            if (languages && Array.isArray(languages) && languages.length > 0) {
              setSupportedLanguages(languages);
            } else {
              // Fallback to common languages if API returns empty array
              setSupportedLanguages([
                'en-US',
                'en-GB',
                'fr-FR',
                'de-DE',
                'it-IT',
                'es-ES',
                'ja-JP',
                'ko-KR',
                'zh-CN',
                'ru-RU',
                'pt-BR',
              ]);
            }
          } catch (langError) {
            console.error('Error getting supported languages:', langError);
            // Fallback languages
            setSupportedLanguages([
              'en-US',
              'en-GB',
              'fr-FR',
              'de-DE',
              'it-IT',
              'es-ES',
              'ja-JP',
              'ko-KR',
              'zh-CN',
              'ru-RU',
              'pt-BR',
            ]);
          }
        }
      } catch (error) {
        console.error(error);
      }
    };

    initialize();

    // Setup event listeners
    const speechStartSubscription = VoiceToText.addEventListener(
      VoiceToTextEvents.START,
      () => {
        setIsListening(true);
        console.log('Speech recognition started');
      }
    );

    const speechEndSubscription = VoiceToText.addEventListener(
      VoiceToTextEvents.END,
      () => {
        setIsListening(false);
        console.log('Speech recognition ended');
      }
    );

    const speechResultsSubscription = VoiceToText.addEventListener(
      VoiceToTextEvents.RESULTS,
      (event) => {
        setResults(event.value || '');
        console.log('Speech results:', event);
      }
    );

    const speechPartialResultsSubscription = VoiceToText.addEventListener(
      VoiceToTextEvents.PARTIAL_RESULTS,
      (event) => {
        setResults(event.value || '');
        console.log('Partial results:', event);
      }
    );

    const speechErrorSubscription = VoiceToText.addEventListener(
      VoiceToTextEvents.ERROR,
      (event) => {
        console.error('Speech recognition error:', event);
        Alert.alert('Error', 'Speech recognition error occurred');
        setIsListening(false);
      }
    );

    // Cleanup
    return () => {
      VoiceToText.destroy();
      speechStartSubscription.remove();
      speechEndSubscription.remove();
      speechResultsSubscription.remove();
      speechPartialResultsSubscription.remove();
      speechErrorSubscription.remove();
    };
  }, []);

  const startRecognition = async () => {
    if (!permissionGranted) {
      const hasPermission = await requestMicrophonePermission();
      if (!hasPermission) return;
    }

    try {
      await VoiceToText.startListening();
    } catch (error) {
      console.error(error);
      Alert.alert('Error', 'Failed to start speech recognition');
    }
  };

  const stopRecognition = async () => {
    try {
      await VoiceToText.stopListening();
    } catch (error) {
      console.error(error);
    }
  };

  const changeLanguage = async (languageTag: string) => {
    try {
      setIsLoading(true);
      const success = await VoiceToText.setRecognitionLanguage(languageTag);
      if (success) {
        setCurrentLanguage(languageTag);
        Alert.alert('Success', `Language changed to ${languageTag}`);
      } else {
        Alert.alert('Error', 'Failed to change language');
      }
    } catch (error: any) {
      console.error('Error setting language:', error);

      // Specific Android thread error handling
      if (
        error.message &&
        error.message.includes(
          'should be used only from the application main thread'
        )
      ) {
        Alert.alert(
          'Android Thread Error',
          'The speech recognizer must run on the main thread. This has been fixed in the latest version.'
        );
      } else {
        Alert.alert('Error', 'Failed to change language');
      }
    } finally {
      setIsLoading(false);
    }
  };

  const refreshSupportedLanguages = async () => {
    try {
      setIsLoading(true);
      const languages = await VoiceToText.getSupportedLanguages();
      if (languages && Array.isArray(languages) && languages.length > 0) {
        setSupportedLanguages(languages);
        Alert.alert('Success', `Found ${languages.length} supported languages`);
      } else {
        // Fallback to common languages if API returns empty array
        const fallbackLanguages = [
          'en-US',
          'en-GB',
          'fr-FR',
          'de-DE',
          'it-IT',
          'es-ES',
          'ja-JP',
          'ko-KR',
          'zh-CN',
          'ru-RU',
          'pt-BR',
        ];
        setSupportedLanguages(fallbackLanguages);
        Alert.alert(
          'Note',
          `API returned no languages. Using ${fallbackLanguages.length} fallback languages instead.`
        );
      }
    } catch (error: any) {
      console.error('Error getting supported languages:', error);
      // Specific Android error handling
      if (
        error.message &&
        (error.message.includes('Cannot convert argument') ||
          error.message.includes('ArrayList'))
      ) {
        Alert.alert(
          'Android Type Error',
          'There was a type conversion error in the native module. This has been fixed in the latest version.'
        );
      }

      // Fallback languages
      const fallbackLanguages = [
        'en-US',
        'en-GB',
        'fr-FR',
        'de-DE',
        'it-IT',
        'es-ES',
        'ja-JP',
        'ko-KR',
        'zh-CN',
        'ru-RU',
        'pt-BR',
      ];
      setSupportedLanguages(fallbackLanguages);
      Alert.alert(
        'Error',
        `Failed to get supported languages. Using ${fallbackLanguages.length} fallback languages instead.`
      );
    } finally {
      setIsLoading(false);
    }
  };

  if (!permissionGranted) {
    return (
      <View style={styles.container}>
        <Text style={styles.message}>Microphone permission is required</Text>
        <Button
          title="Grant Permission"
          onPress={requestMicrophonePermission}
        />
      </View>
    );
  }

  if (!isAvailable) {
    return (
      <View style={styles.container}>
        <Text style={styles.message}>
          Speech recognition is not available on this device.
        </Text>
      </View>
    );
  }

  return (
    <ScrollView contentContainerStyle={styles.scrollContainer}>
      <View style={styles.container}>
        <Text style={styles.language}>Current language: {currentLanguage}</Text>

        <View style={styles.resultContainer}>
          <Text style={styles.result}>{results || 'Say something...'}</Text>
        </View>

        {isListening && (
          <ActivityIndicator
            size="large"
            color="#0000ff"
            style={styles.indicator}
          />
        )}

        <Button
          title={isListening ? 'Stop Listening' : 'Start Listening'}
          onPress={isListening ? stopRecognition : startRecognition}
        />

        <View style={styles.sectionContainer}>
          <Text style={styles.sectionTitle}>Language Settings</Text>

          <Button
            title="Refresh Supported Languages"
            onPress={refreshSupportedLanguages}
            disabled={isLoading}
          />

          {isLoading && (
            <ActivityIndicator
              size="small"
              color="#0000ff"
              style={styles.indicator}
            />
          )}

          <Text style={styles.subsectionTitle}>
            Supported Languages ({supportedLanguages.length})
          </Text>

          <View style={styles.languageList}>
            {supportedLanguages.map((lang) => (
              <TouchableOpacity
                key={lang}
                style={[
                  styles.languageButton,
                  currentLanguage === lang && styles.activeLanguageButton,
                ]}
                onPress={() => changeLanguage(lang)}
                disabled={isLoading}
              >
                <Text
                  style={[
                    styles.languageButtonText,
                    currentLanguage === lang && styles.activeLanguageButtonText,
                  ]}
                >
                  {lang}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scrollContainer: {
    flexGrow: 1,
  },
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 20,
    backgroundColor: '#f5f5f5',
  },
  language: {
    marginBottom: 20,
    fontSize: 16,
    color: '#555',
  },
  resultContainer: {
    width: '100%',
    minHeight: 100,
    marginBottom: 30,
    padding: 15,
    backgroundColor: 'white',
    borderRadius: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 2,
  },
  result: {
    fontSize: 18,
    textAlign: 'center',
    color: '#333',
  },
  indicator: {
    marginBottom: 20,
  },
  message: {
    fontSize: 16,
    marginBottom: 20,
    textAlign: 'center',
    color: '#555',
  },
  sectionContainer: {
    width: '100%',
    marginTop: 30,
    padding: 15,
    backgroundColor: 'white',
    borderRadius: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 2,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 15,
    color: '#333',
  },
  subsectionTitle: {
    fontSize: 16,
    marginTop: 15,
    marginBottom: 10,
    color: '#555',
  },
  languageList: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'flex-start',
  },
  languageButton: {
    backgroundColor: '#f0f0f0',
    padding: 10,
    margin: 5,
    borderRadius: 5,
    minWidth: 80,
    alignItems: 'center',
  },
  activeLanguageButton: {
    backgroundColor: '#4a90e2',
  },
  languageButtonText: {
    color: '#333',
  },
  activeLanguageButtonText: {
    color: 'white',
    fontWeight: 'bold',
  },
});
