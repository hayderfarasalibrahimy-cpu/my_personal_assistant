import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart'; // for navigatorKey

class ToastService {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;

  /// عرض إشعار تراجع مخصص يطفو فوق الشاشة
  static void showUndoToast(
    BuildContext context,
    String message,
    VoidCallback onUndo,
  ) {
    _show(context, message, onUndo: onUndo);
  }

  static void showSuccessToast(BuildContext context, String message) {
    _show(context, message);
  }

  static void showErrorToast(BuildContext context, String message) {
    _show(context, message, isError: true);
  }

  static void _show(
    BuildContext context,
    String message, {
    VoidCallback? onUndo,
    bool isError = false,
  }) {
    // 1. إزالة أي إشعار سابق فوراً
    dismiss();

    const duration = Duration(seconds: 5);

    // 2. إنشاء OverlayEntry جديد
    _currentEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 80, // يرتفع قليلاً عن الأسفل لتجنب التداخل مع التنقل
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: _UndoToastWidget(
            message: message,
            duration: duration,
            isError: isError,
            onUndo: onUndo != null
                ? () {
                    onUndo();
                    dismiss(); // إخفاء فور الضغط على تراجع
                  }
                : null,
          ),
        ),
      ),
    );

    // 3. إضافته إلى الـ Overlay
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay != null) {
      overlay.insert(_currentEntry!);

      // 4. مؤقت صارم للإخفاء بعد 5 ثوانٍ
      _timer = Timer(duration, () {
        dismiss();
      });
    }
  }

  /// إخفاء الإشعار الحالي
  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _UndoToastWidget extends StatefulWidget {
  final String message;
  final Duration duration;
  final VoidCallback? onUndo;
  final bool isError;

  const _UndoToastWidget({
    required this.message,
    required this.duration,
    this.onUndo,
    this.isError = false,
  });

  @override
  State<_UndoToastWidget> createState() => _UndoToastWidgetState();
}

class _UndoToastWidgetState extends State<_UndoToastWidget>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _progressController;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    // Entry Animation
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));

    _entryController.forward();

    // Progress Bar Animation
    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _progressController.reverse(from: 1.0); // Start full and decrease
  }

  @override
  void dispose() {
    _entryController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // استخدام الثيم الحالي للألوان
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isError
                ? Colors.red.shade800
                : (isDark ? Colors.grey[800] : Colors.grey[900]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (widget.onUndo != null) ...[
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: widget.onUndo,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.amber,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: Colors.amber.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.undo, size: 16, color: Colors.amber),
                            SizedBox(width: 4),
                            Text(
                              'تراجع',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Loading Bar
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: _progressController.value,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.amber.withValues(alpha: 0.5),
                      ),
                      minHeight: 4,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
