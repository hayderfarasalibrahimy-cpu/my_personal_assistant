import 'package:flutter/material.dart';
import '../services/spell_check_service.dart' as custom_spell;
import '../services/auto_numbering_service.dart';
import '../utils/text_utils.dart';

/// حقل نص ذكي مع دعم التدقيق الإملائي والترقيم التلقائي
class SmartTextField extends StatefulWidget {
  final SmartTextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final int? maxLines;
  final int? minLines;
  final bool enableSpellCheck;
  final bool enableAutoNumbering;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final InputDecoration? decoration;
  final TextStyle? style;
  final bool showWordCount;

  const SmartTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.maxLines,
    this.minLines,
    this.enableSpellCheck = true,
    this.enableAutoNumbering = true,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.decoration,
    this.style,
    this.showWordCount = false,
  });

  @override
  State<SmartTextField> createState() => _SmartTextFieldState();
}

class _SmartTextFieldState extends State<SmartTextField> {
  late SmartTextEditingController _controller;
  final custom_spell.SpellCheckServiceCustom _spellCheckService =
      custom_spell.SpellCheckServiceCustom.instance;
  List<custom_spell.SpellError> _spellErrors = [];
  int _wordCount = 0;
  int _charCount = 0;
  String _lastText = '';
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        SmartTextEditingController(enableSpellCheck: widget.enableSpellCheck);
    _initializeSpellCheck();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeSpellCheck() async {
    if (widget.enableSpellCheck) {
      await _spellCheckService.initialize();
      setState(() {});
    }
  }

  void _onTextChanged() {
    final currentText = _controller.text;

    // التحقق من التدقيق الإملائي
    if (widget.enableSpellCheck) {
      setState(() {
        _spellErrors = _spellCheckService.checkText(_controller.text);
      });
    }

    // التحقق من الترقيم التلقائي
    if (widget.enableAutoNumbering && currentText.length > _lastText.length) {
      _handleAutoNumbering(currentText);
    }

    // تحديث عداد الكلمات
    if (widget.showWordCount) {
      _updateWordCount();
    }

    // التحقق من الـ validator
    if (widget.validator != null) {
      setState(() {
        _errorText = widget.validator!(_controller.text);
      });
    }

    _lastText = currentText;
  }

  void _handleAutoNumbering(String text) {
    // التحقق من الضغط على Enter
    if (text.endsWith('\n')) {
      final lines = text.split('\n');
      if (lines.length >= 2) {
        final previousLine = lines[lines.length - 2];
        final pattern = AutoNumberingService.detectNumberingPattern(
          previousLine,
        );

        if (pattern != null) {
          final nextNumber = AutoNumberingService.getNextNumber(
            pattern,
            previousLine,
          );
          final newText = '$text$nextNumber ';

          _controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          );
        }
      }
    }
  }

  void _updateWordCount() {
    final text = _controller.text;
    final words = text.trim().split(RegExp(r'\s+'));
    setState(() {
      _wordCount = words.where((word) => word.isNotEmpty).length;
      _charCount = text.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          decoration:
              widget.decoration ??
              InputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                errorText: _errorText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                alignLabelWithHint: true,
              ),
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          keyboardType: widget.keyboardType ?? TextInputType.multiline,
          textInputAction: widget.textInputAction,
          textDirection: TextUtils.getTextDirection(_controller.text),
          textAlign: TextUtils.getTextAlign(_controller.text),
          style: widget.style,
        ),

        // عرض عداد الكلمات
        if (widget.showWordCount)
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '$_wordCount كلمة • $_charCount حرف',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

        // عرض عدد الأخطاء الإملائية
        if (widget.enableSpellCheck && _spellErrors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 12),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 14, color: Colors.red),
                const SizedBox(width: 4),
                Text(
                  '${_spellErrors.length} خطأ إملائي',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// TextEditingController مخصص مع دعم التدقيق الإملائي
class SmartTextEditingController extends TextEditingController {
  final custom_spell.SpellCheckServiceCustom _spellCheckService =
      custom_spell.SpellCheckServiceCustom.instance;
  bool enableSpellCheck;

  SmartTextEditingController({super.text, this.enableSpellCheck = true});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (!enableSpellCheck) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final errors = _spellCheckService.checkText(text);
    if (errors.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final List<TextSpan> spans = [];
    int currentPosition = 0;

    for (final error in errors) {
      // إضافة النص الصحيح قبل الخطأ
      if (error.startIndex > currentPosition) {
        spans.add(
          TextSpan(
            text: text.substring(currentPosition, error.startIndex),
            style: style,
          ),
        );
      }

      // إضافة الكلمة الخاطئة مع خط أحمر
      spans.add(
        TextSpan(
          text: text.substring(error.startIndex, error.endIndex),
          style: style?.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: Colors.red,
            decorationStyle: TextDecorationStyle.wavy,
            decorationThickness: 2,
          ),
        ),
      );

      currentPosition = error.endIndex;
    }

    // إضافة النص المتبقي
    if (currentPosition < text.length) {
      spans.add(TextSpan(text: text.substring(currentPosition), style: style));
    }

    return TextSpan(style: style, children: spans);
  }
}
