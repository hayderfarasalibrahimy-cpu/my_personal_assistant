import 'package:flutter/material.dart';
import 'dart:math' as math;

/// ويدجت لعرض موجات صوتية متحركة أثناء التسجيل
class AudioWaveWidget extends StatefulWidget {
  final double amplitude; // 0.0 - 1.0
  final Color color;
  final double width;
  final double height;
  final int barCount;

  const AudioWaveWidget({
    super.key,
    required this.amplitude,
    this.color = Colors.red,
    this.width = 100,
    this.height = 40,
    this.barCount = 5,
  });

  @override
  State<AudioWaveWidget> createState() => _AudioWaveWidgetState();
}

class _AudioWaveWidgetState extends State<AudioWaveWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final List<double> _barHeights = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat();

    // تهيئة ارتفاعات الأعمدة
    for (int i = 0; i < widget.barCount; i++) {
      _barHeights.add(0.2);
    }
  }

  @override
  void didUpdateWidget(AudioWaveWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // تحديث ارتفاعات الأعمدة بناءً على amplitude
    _updateBarHeights();
  }

  void _updateBarHeights() {
    final random = math.Random();
    for (int i = 0; i < widget.barCount; i++) {
      // إضافة تنوع عشوائي بناءً على amplitude
      final baseHeight = 0.2 + widget.amplitude * 0.8;
      _barHeights[i] = (baseHeight * (0.5 + random.nextDouble() * 0.5)).clamp(
        0.1,
        1.0,
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        _updateBarHeights();
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.barCount, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: widget.width / (widget.barCount * 2),
                height: widget.height * _barHeights[index],
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
