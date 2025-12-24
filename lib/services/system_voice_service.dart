import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class SystemVoiceService {
  static const MethodChannel _channel = MethodChannel(
    'com.hayderfiras.mudhkira/voice',
  );

  /// Start the system voice recognition functionality.
  /// returns the recognized text or throws an error.
  static Future<String?> startVoiceRecognition() async {
    try {
      final String? result = await _channel.invokeMethod(
        'startVoiceRecognition',
      );
      return result;
    } on PlatformException catch (e) {
      if (e.code == "CANCELED") {
        debugPrint("Voice recognition canceled by user.");
        return null;
      }
      debugPrint("Failed to start voice recognition: '${e.message}'.");
      rethrow;
    }
  }
}
