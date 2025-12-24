import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class VoiceRecorderService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _currentPath;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// التحقق من الأذونات
  Future<bool> hasPermission() async {
    // Android/iOS permission
    if (!Platform.isWindows) {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        return false;
      }
    }

    // Check record package permission
    return await _audioRecorder.hasPermission();
  }

  /// بدء التسجيل
  Future<void> startRecording() async {
    try {
      if (await hasPermission()) {
        final dir = await getTemporaryDirectory();
        final fileName =
            'audio_${DateTime.now().millisecondsSinceEpoch}.m4a'; // m4a for compatibility
        _currentPath = '${dir.path}/$fileName';

        // تكوين التسجيل (AAC HE للصوت البشري)
        const config = RecordConfig(encoder: AudioEncoder.aacLc);

        await _audioRecorder.start(config, path: _currentPath!);
        _isRecording = true;
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _isRecording = false;
    }
  }

  /// إيقاف التسجيل وإرجاع المسار
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) return null;

      final path = await _audioRecorder.stop();
      _isRecording = false;
      return path;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      return null;
    }
  }

  /// إلغاء التسجيل وحذف الملف
  Future<void> cancelRecording() async {
    try {
      if (!_isRecording) return;

      final path = await _audioRecorder.stop();
      _isRecording = false;

      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Error cancelling recording: $e');
    }
  }

  /// الحصول على مستوى الصوت الحالي (0.0 - 1.0)
  Future<double> getAmplitude() async {
    try {
      if (!_isRecording) return 0.0;

      final amplitude = await _audioRecorder.getAmplitude();
      // تحويل الديسيبل إلى نسبة (0.0 - 1.0)
      // الديسيبل يتراوح من -160 (صمت) إلى 0 (أعلى صوت)
      final db = amplitude.current;
      if (db < -60) return 0.0;
      if (db > 0) return 1.0;
      return (db + 60) / 60; // تطبيع من -60 db إلى 0 db
    } catch (e) {
      return 0.0;
    }
  }

  /// تحرير الموارد
  void dispose() {
    _audioRecorder.dispose();
  }
}
