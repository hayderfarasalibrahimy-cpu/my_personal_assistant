import 'package:flutter/material.dart';
import 'glass_widgets.dart';

/// زر عائم منبثق مع أيقونات فرعية (Speed Dial)
class AnimatedSpeedDial extends StatefulWidget {
  final List<SpeedDialChild> children;
  final Widget? mainIcon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AnimatedSpeedDial({
    super.key,
    required this.children,
    this.mainIcon,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<AnimatedSpeedDial> createState() => _AnimatedSpeedDialState();
}

class _AnimatedSpeedDialState extends State<AnimatedSpeedDial>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // الأزرار الفرعية
        if (_isOpen)
          ...List.generate(widget.children.length, (index) {
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 150 + (index * 50)),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, (1 - value) * 20),
                  child: Opacity(
                    opacity: value,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildChildButton(widget.children[index]),
                    ),
                  ),
                );
              },
            );
          }),

        // الزر الرئيسي
        GestureDetector(
          onTap: _toggle,
          child: GlassContainer(
            width: 56,
            height: 56,
            borderRadius: BorderRadius.circular(28),
            blur: 15,
            opacity: 0.2,
            color:
                widget.backgroundColor ?? Theme.of(context).colorScheme.primary,
            border: Border.all(
              color:
                  (widget.backgroundColor ??
                          Theme.of(context).colorScheme.primary)
                      .withValues(alpha: 0.4),
              width: 1.5,
            ),
            child: Center(
              child: AnimatedRotation(
                turns: _isOpen ? 0.125 : 0, // 45 درجة = 1/8 من الدورة
                duration: const Duration(milliseconds: 300),
                child: IconTheme(
                  data: IconThemeData(
                    color: widget.foregroundColor ?? Colors.white,
                    size: 24,
                  ),
                  child: widget.mainIcon ?? const Icon(Icons.add),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChildButton(SpeedDialChild child) {
    return GestureDetector(
      onTap: () {
        _toggle();
        child.onTap?.call();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // التسمية
          if (child.label != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                blur: 10,
                opacity: 0.15,
                borderRadius: BorderRadius.circular(10),
                child: Text(
                  child.label!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),

          // الزر الفرعي
          GlassContainer(
            width: 40,
            height: 40,
            borderRadius: BorderRadius.circular(20),
            blur: 10,
            opacity: 0.15,
            color:
                child.backgroundColor ??
                Theme.of(context).colorScheme.secondary,
            border: Border.all(
              color:
                  (child.backgroundColor ??
                          Theme.of(context).colorScheme.secondary)
                      .withValues(alpha: 0.3),
              width: 1,
            ),
            child: Center(
              child: IconTheme(
                data: IconThemeData(
                  color: child.foregroundColor ?? Colors.white,
                  size: 20,
                ),
                child: child.icon,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// بيانات الزر الفرعي
class SpeedDialChild {
  final Widget icon;
  final String? label;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;

  SpeedDialChild({
    required this.icon,
    this.label,
    this.onTap,
    this.backgroundColor,
    this.foregroundColor,
  });
}
