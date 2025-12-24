import 'dart:ui';
import 'package:flutter/material.dart';

/// تأثير زجاجي قابل لإعادة الاستخدام
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Border? border;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 8, // Reduced from 10
    this.opacity = 0.08, // Reduced from 0.1
    this.borderRadius,
    this.padding,
    this.margin,
    this.color,
    this.border,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = color ?? (isDark ? Colors.white : Colors.black);

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius:
            borderRadius ?? BorderRadius.circular(12), // Reduced from 16
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: opacity),
              borderRadius:
                  borderRadius ?? BorderRadius.circular(12), // Reduced from 16
              border:
                  border ??
                  Border.all(
                    color: baseColor.withValues(alpha: 0.25),
                    width: 1.2,
                  ), // Reduced width and opacity
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// نص مع ظل لضمان الوضوح
class ShadowedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const ShadowedText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shadowColor = isDark ? Colors.black : Colors.white;

    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(
        shadows: [
          Shadow(
            color: shadowColor.withValues(alpha: 0.8),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
          Shadow(
            color: shadowColor.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}

/// أيقونة مع ظل
class ShadowedIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;

  const ShadowedIcon(this.icon, {super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shadowColor = isDark ? Colors.black : Colors.white;

    return Stack(
      children: [
        // الظل
        Icon(icon, size: size, color: shadowColor.withValues(alpha: 0.5)),
        // الأيقونة
        Icon(icon, size: size, color: color),
      ],
    );
  }
}
