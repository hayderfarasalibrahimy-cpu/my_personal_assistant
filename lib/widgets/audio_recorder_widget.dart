import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import '../services/gemini_service.dart';
import '../services/explanation_service.dart';

class AudioRecorderWidget extends StatefulWidget {
  final Function(List<String> paths) onRecordingsChanged;
  final Function(String transcription)? onTranscribe;
  final List<String> existingAudioPaths;

  const AudioRecorderWidget({
    super.key,
    required this.onRecordingsChanged,
    this.onTranscribe,
    this.existingAudioPaths = const [],
  });

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget> {
  late final AudioRecorder _audioRecorder;
  late final AudioPlayer _audioPlayer;
  bool _isRecording = false;

  // حالة التشغيل
  String? _playingPath; // المسار الذي يتم تشغيله حالياً
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  late List<String> _audioPaths;
  final Map<String, int> _audioDurations = {}; // مدة كل تسجيل بالثواني
  final Set<String> _transcribingPaths = {}; // المسارات التي يتم تحويلها الآن

  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _playerPositionSubscription;
  StreamSubscription? _playerDurationSubscription;
  StreamSubscription? _amplitudeSubscription;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  // للموجات الصوتية (للتسجيل)
  final List<double> _amplitudes = [];

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    _audioPaths = List.from(widget.existingAudioPaths);

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playingPath = null;
          _currentPosition = Duration.zero;
        });
      }
    });

    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((
      state,
    ) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _playerPositionSubscription = _audioPlayer.onPositionChanged.listen((
      position,
    ) {
      if (mounted) {
        setState(() => _currentPosition = position);
      }
    });

    _playerDurationSubscription = _audioPlayer.onDurationChanged.listen((
      duration,
    ) {
      if (mounted) {
        setState(() => _totalDuration = duration);
      }
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _playerCompleteSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _playerPositionSubscription?.cancel();
    _playerDurationSubscription?.cancel();
    _amplitudeSubscription?.cancel();
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        // إيقاف أي تشغيل حالي
        if (_isPlaying) await _audioPlayer.stop();

        final dir = await getApplicationDocumentsDirectory();
        final path = p.join(
          dir.path,
          'recording_${DateTime.now().millisecondsSinceEpoch}.m4a',
        );

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordingSeconds = 0;
          _amplitudes.clear();
        });

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) setState(() => _recordingSeconds++);
        });

        _amplitudeSubscription = _audioRecorder
            .onAmplitudeChanged(const Duration(milliseconds: 100))
            .listen((amplitude) {
              if (mounted) {
                setState(() {
                  double normalized = (amplitude.current + 160) / 160;
                  if (normalized < 0) normalized = 0;
                  if (normalized > 1) normalized = 1;
                  _amplitudes.add(normalized);
                  if (_amplitudes.length > 40) _amplitudes.removeAt(0);
                });
              }
            });
      }
    } catch (e) {
      debugPrint('Error starting record: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      _amplitudeSubscription?.cancel();
      final path = await _audioRecorder.stop();
      final duration = _recordingSeconds; // حفظ المدة قبل إعادة التعيين

      if (path != null) {
        setState(() {
          _isRecording = false;
          _audioPaths.add(path);
          _audioDurations[path] = duration; // حفظ مدة التسجيل
        });
        widget.onRecordingsChanged(_audioPaths);
      }
    } catch (e) {
      debugPrint('Error stopping record: $e');
    }
  }

  Future<void> _playAudio(String path) async {
    try {
      if (_playingPath == path && _isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play(DeviceFileSource(path));
        setState(() {
          _playingPath = path;
        });
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  void _deleteAudio(int index) {
    if (_playingPath == _audioPaths[index]) {
      _audioPlayer.stop();
      _playingPath = null;
    }
    setState(() {
      _audioPaths.removeAt(index);
    });
    widget.onRecordingsChanged(_audioPaths);
  }

  Future<void> _handleTranscribe(String path) async {
    if (widget.onTranscribe == null) return;

    ExplanationService.showExplanationDialog(
      context: context,
      featureKey: 'transcribe_audio',
      title: 'تحويل الصوت إلى نص',
      explanation:
          'سأقوم بتحليل المقطع الصوتي المسجل وتحويله إلى نص مكتوب بدقة باستخدام الذكاء الاصطناعي، ثم إضافته مباشرة إلى ملاحظتك.',
      onProceed: () async {
        setState(() => _transcribingPaths.add(path));
        try {
          final bytes = await File(path).readAsBytes();
          final text = await GeminiService.transcribeAudio(bytes);
          if (text.isNotEmpty) {
            widget.onTranscribe!(text);
          }
        } catch (e) {
          debugPrint('Error in _handleTranscribe: $e');
        } finally {
          if (mounted) {
            setState(() => _transcribingPaths.remove(path));
          }
        }
      },
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// استخراج معلومات التسجيل من مسار الملف
  String _getRecordingInfo(String path) {
    try {
      // اسم الملف يحتوي على timestamp: recording_1702345678901.m4a
      final fileName = p.basenameWithoutExtension(path);
      final parts = fileName.split('_');
      if (parts.length >= 2) {
        final timestamp = int.tryParse(parts.last);
        if (timestamp != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final day = date.day.toString().padLeft(2, '0');
          final month = date.month.toString().padLeft(2, '0');
          final year = date.year;
          final hour = date.hour.toString().padLeft(2, '0');
          final minute = date.minute.toString().padLeft(2, '0');
          return '$day/$month/$year - $hour:$minute';
        }
      }
    } catch (e) {
      // تجاهل الأخطاء
    }
    return 'تسجيل صوتي';
  }

  Widget _buildWaveVisualizer() {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _amplitudes.map((amp) {
          double height = 4 + (30 * amp);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            width: 4,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(50),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // قائمة التسجيلات
        if (_audioPaths.isNotEmpty) ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _audioPaths.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final path = _audioPaths[index];
              final isPlayingThis = _playingPath == path && _isPlaying;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPlayingThis ? primaryColor : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      child: IconButton(
                        icon: Icon(
                          isPlayingThis ? Icons.pause : Icons.play_arrow,
                          color: primaryColor,
                        ),
                        onPressed: () => _playAudio(path),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'تسجيل ${index + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              // عرض المدة المحفوظة أو مدة التشغيل
                              Builder(
                                builder: (context) {
                                  if (isPlayingThis &&
                                      _totalDuration.inSeconds > 0) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${_formatDuration(_currentPosition.inSeconds)} / ${_formatDuration(_totalDuration.inSeconds)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : primaryColor,
                                        ),
                                      ),
                                    );
                                  } else if (_audioDurations.containsKey(
                                    path,
                                  )) {
                                    return Text(
                                      _formatDuration(_audioDurations[path]!),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // عرض تاريخ ووقت التسجيل
                          Text(
                            _getRecordingInfo(path),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                          if (isPlayingThis)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: LinearProgressIndicator(
                                value: _totalDuration.inMilliseconds > 0
                                    ? _currentPosition.inMilliseconds /
                                          _totalDuration.inMilliseconds
                                    : 0,
                                backgroundColor: primaryColor.withValues(
                                  alpha: 0.1,
                                ),
                                valueColor: AlwaysStoppedAnimation(
                                  primaryColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (widget.onTranscribe != null)
                      _transcribingPaths.contains(path)
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: Padding(
                                padding: EdgeInsets.all(4.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.blue,
                                  ),
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.description_outlined,
                                color: Colors.blue,
                                size: 20,
                              ),
                              onPressed: () => _handleTranscribe(path),
                              tooltip: 'تحويل الصوت إلى نص',
                            ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteAudio(index),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],

        // واجهة التسجيل
        if (_isRecording)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade400, Colors.red.shade600],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildWaveVisualizer(),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.mic, color: Colors.white),
                    const SizedBox(width: 16),
                    Text(
                      _formatDuration(_recordingSeconds),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _stopRecording,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.stop, color: Colors.red.shade600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          InkWell(
            onTap: _startRecording,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.grey[600]!
                      : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic, color: primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'تسجيل مقطع صوتي جديد',
                    style: TextStyle(
                      color: isDark ? Colors.white : primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
