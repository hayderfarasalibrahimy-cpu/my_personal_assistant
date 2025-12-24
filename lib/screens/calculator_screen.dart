import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
// ignore: depend_on_referenced_packages
import 'package:number_to_word_arabic/number_to_word_arabic.dart';
import '../widgets/glass_widgets.dart';
import '../utils/app_snackbar.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen>
    with TickerProviderStateMixin {
  String _expression = '';
  String _previewResult = '';
  List<Map<String, String>> _history = [];
  bool _isScientific = false;

  late AnimationController _resultController;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _textScrollController = ScrollController();
  final ScrollController _historyScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadHistory();

    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _resultController.dispose();
    _textController.dispose();
    _textScrollController.dispose();
    _historyScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('calc_history') ?? [];
    setState(() {
      _history = historyJson
          .map((e) => Map<String, String>.from(json.decode(e)))
          .toList();
    });
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = _history.map((e) => json.encode(e)).toList();
    await prefs.setStringList('calc_history', historyJson);
  }

  void _addToHistory(String expr, String res) {
    setState(() {
      _history.insert(0, {'expression': expr, 'result': res});
      if (_history.length > 50) _history.removeLast();
    });
    _saveHistory();
  }

  void _updateExpression(String newExpr) {
    setState(() {
      _expression = newExpr;
      _textController.text = _formatExpressionDisplay(_expression);

      // Auto-scroll to end after frame build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_textScrollController.hasClients) {
          _textScrollController.animateTo(
            _textScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  void _onPressed(String text) async {
    HapticFeedback.lightImpact();

    String nextExpr = _expression;

    if (text == 'AC') {
      nextExpr = '';
      setState(() {
        _previewResult = '';
      });
    } else if (text == '⌫') {
      if (nextExpr.isNotEmpty) {
        nextExpr = nextExpr.substring(0, nextExpr.length - 1);
      }
    } else if (text == '=') {
      if (_previewResult.isNotEmpty && _previewResult != 'Error') {
        _addToHistory(_expression, _previewResult);
        nextExpr = _previewResult.replaceAll(',', '');
        setState(() {
          _previewResult = '';
          _resultController.forward(from: 0.0);
        });
      }
    } else if (text == '.') {
      if (_canAddDecimal(nextExpr)) {
        nextExpr += text;
      }
    } else {
      if (_isOperator(text) &&
          nextExpr.isNotEmpty &&
          _isOperator(nextExpr[nextExpr.length - 1])) {
        nextExpr = nextExpr.substring(0, nextExpr.length - 1) + text;
      } else {
        if (nextExpr == '0' || nextExpr == 'Error') {
          nextExpr = text;
        } else {
          nextExpr += text;
        }
      }
    }

    _updateExpression(nextExpr);

    if (text != '=' && text != 'AC') {
      _calculatePreview();
    }
  }

  bool _canAddDecimal(String expression) {
    if (expression.isEmpty) return true;
    int lastOperatorIndex = -1;
    for (int i = expression.length - 1; i >= 0; i--) {
      if (_isOperator(expression[i])) {
        lastOperatorIndex = i;
        break;
      }
    }
    String lastNumber = expression.substring(lastOperatorIndex + 1);
    return !lastNumber.contains('.');
  }

  bool _isOperator(String text) {
    return ['+', '-', '×', '÷', '%', '^'].contains(text);
  }

  void _calculatePreview() {
    if (_expression.isEmpty ||
        _isOperator(_expression[_expression.length - 1])) {
      // Don't clear preview immediately if still typing valid operators,
      // but maybe just keep old preview? For now let's not clear it blindly.
      return;
    }
    try {
      final val = _evaluate(_expression);
      final formatted = _formatResult(val);
      setState(() {
        _previewResult = formatted;
      });
    } catch (e) {
      setState(() {
        _previewResult = '';
      });
    }
  }

  String _formatResult(double value) {
    if (value.isInfinite || value.isNaN) return 'Error';
    final formatter = NumberFormat("#,###.########", "en_US");
    return formatter.format(value);
  }

  String _formatExpressionDisplay(String expression) {
    return expression.replaceAllMapped(RegExp(r'(\d+)(\.\d+)?'), (Match m) {
      String part = m[0]!;
      if (part.contains('.')) {
        List<String> split = part.split('.');
        String integerPart = split[0];
        String decimalPart = split.length > 1 ? split[1] : '';
        String formattedInt = NumberFormat(
          "#,###",
          "en_US",
        ).format(int.parse(integerPart.isEmpty ? '0' : integerPart));
        if (integerPart.isEmpty && part.startsWith('.')) {
          formattedInt = '';
        }
        return "$formattedInt.$decimalPart";
      } else {
        if (part.length > 15) return part; // Avoid overflow parsing large longs
        return NumberFormat("#,###", "en_US").format(int.parse(part));
      }
    });
  }

  // --- Evaluation Logic (Unchanged) ---
  double _evaluate(String expression) {
    String finalExpr = expression
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('π', math.pi.toString())
        .replaceAll('e', math.e.toString());

    finalExpr = finalExpr.replaceAllMapped(
      RegExp(r'(\d)(\()'),
      (Match m) => "${m[1]}*${m[2]}",
    );
    finalExpr = finalExpr.replaceAllMapped(
      RegExp(r'(\))(\d)'),
      (Match m) => "${m[1]}*${m[2]}",
    );

    try {
      Parser parser = Parser();
      Expression exp = parser.parse(finalExpr);
      return exp.evaluate();
    } catch (e) {
      throw Exception('Invalid Expression');
    }
  }

  String _getTafqeetString() {
    String textToConvert = _previewResult.isEmpty
        ? _expression
        : _previewResult;
    textToConvert = textToConvert.replaceAll(',', '');

    if (textToConvert.isEmpty || textToConvert == 'Error') return '';

    try {
      if (textToConvert.contains('.')) {
        double val = double.parse(textToConvert);
        textToConvert = val.floor().toString();
      }

      // Basic check to ensure it is digits only
      if (!RegExp(r'^\d+$').hasMatch(textToConvert)) return '';

      return Tafqeet.convert(textToConvert);
    } catch (e) {
      return '';
    }
  }

  void _copyAsTafqeet() {
    String textToConvert = _previewResult.isEmpty
        ? _expression
        : _previewResult;
    textToConvert = textToConvert.replaceAll(',', '');

    if (textToConvert.isEmpty || textToConvert == 'Error') {
      AppSnackBar.warning(context, 'لا يوجد رقم لتحويله');
      return;
    }

    try {
      double val = double.parse(textToConvert);
      int intVal = val.floor();
      String tafqeetText = Tafqeet.convert(intVal.toString());
      String fullText = "$tafqeetText دينار عراقي";

      Clipboard.setData(ClipboardData(text: fullText));
      AppSnackBar.success(context, 'تم النسخ: $fullText');
    } catch (e) {
      AppSnackBar.error(context, 'خطأ في تحويل الرقم');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    final bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [Colors.black, const Color(0xFF1A1A2E)]
          : [Colors.grey[100]!, Colors.blueGrey[50]!],
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(''),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        actions: [
          // Tafqeet Button
          IconButton(
            icon: Icon(
              Icons.receipt_long, // Suggesting receipt/text ver.
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            tooltip: 'نسخ كتابة (تفقيط)',
            onPressed: _copyAsTafqeet,
          ),
          IconButton(
            icon: Icon(
              _isScientific ? Icons.calculate : Icons.functions,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            onPressed: () => setState(() => _isScientific = !_isScientific),
          ),
          Builder(
            builder: (context) => IconButton(
              icon: Icon(
                Icons.history,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: _buildHistoryDrawer(isDark, primaryColor),
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: Stack(
          children: [
            // Removed glow orbs to fix purple rectangle issue
            SafeArea(
              child: Column(
                children: [
                  // Display Area
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      alignment: Alignment.bottomRight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Main Expression (TextField)
                          _buildExpressionField(isDark),
                          const SizedBox(height: 12),
                          // Real-time Preview (Stable Height)
                          SizedBox(
                            height:
                                90, // زيادة الارتفاع لاستيعاب سطرين من التفقيط
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildPreviewText(isDark, primaryColor),
                                _buildRealTimeTafqeet(isDark),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Keypad
                  Expanded(
                    flex: 6,
                    child: GlassContainer(
                      opacity: isDark ? 0.3 : 0.8,
                      blur: 20,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _buildKeypad(isDark, primaryColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Removed unused _buildGlowOrb

  Widget _buildExpressionField(bool isDark) {
    return AnimatedBuilder(
      animation: _resultController,
      builder: (context, child) {
        double scale = 1.0;
        if (_resultController.status == AnimationStatus.forward) {
          scale = 1.0 + (_resultController.value * 0.1);
          if (_resultController.value > 0.5) {
            scale = 1.1 - ((_resultController.value - 0.5) * 0.2);
          }
        }
        return Transform.scale(
          scale: scale,
          alignment: Alignment.centerRight,
          child: TextField(
            controller: _textController,
            scrollController: _textScrollController,
            readOnly: true,
            showCursor: true,
            autofocus: true,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.normal,
              color: isDark ? Colors.white : Colors.black87,
              height: 1.2,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            keyboardType: TextInputType.none,
            maxLines: 1,
            onChanged: (val) {
              // Ensure we keep scrolling to end if text changes (though it's readOnly here,
              // programmatically changing text content triggers this if notified)
            },
          ),
        );
      },
    );
  }

  Widget _buildPreviewText(bool isDark, Color primary) {
    // Using simple text inside SizedBox
    if (_previewResult.isEmpty) return const SizedBox.shrink();

    return Container(
      alignment: Alignment.centerRight,
      child: Text(
        _previewResult,
        style: TextStyle(
          fontSize: 26, // تصغير من 28 إلى 26
          fontWeight: FontWeight.w500,
          color: _previewResult == 'Error'
              ? Colors.redAccent
              : (isDark
                    ? Colors.cyanAccent.withValues(alpha: 0.9)
                    : primary.withValues(alpha: 0.8)),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildRealTimeTafqeet(bool isDark) {
    String tafqeet = _getTafqeetString();
    if (tafqeet.isEmpty) return const SizedBox.shrink();

    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        "$tafqeet دينار عراقي",
        style: TextStyle(
          fontSize: 11, // تصغير من 13 إلى 11
          fontWeight: FontWeight.w300,
          color: isDark ? Colors.white54 : Colors.grey[700],
          height: 1.2,
        ),
        maxLines: 3, // زيادة إلى 3 أسطر
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _buildKeypad(bool isDark, Color primary) {
    // Standard Layout
    final buttons = _isScientific
        ? [
            ['sin', 'cos', 'tan', 'AC', '⌫'],
            ['ln', 'log', '^', '%', '÷'],
            ['(', '7', '8', '9', '×'],
            [')', '4', '5', '6', '-'],
            ['sqrt', '1', '2', '3', '+'],
            ['exit', '0', '000', '.', '='],
          ]
        : [
            ['AC', '⌫', '%', '÷'],
            ['7', '8', '9', '×'],
            ['4', '5', '6', '-'],
            ['1', '2', '3', '+'],
            ['000', '0', '.', '='],
          ];

    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: buttons.map((row) {
          return Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((text) {
                return Expanded(
                  child: _buildGlassButton(text, isDark, primary),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  // _buildGlassButton and _buildHistoryDrawer and Parser classes follow here unchanged...
  // (We need to keep them or the file will break if we don't include them in the replacement if we are replacing the whole class range)
  // Since the replacement range was start of file to line 655 (end of _CalculatorScreenState),
  // we must ensure we include _buildGlassButton and _buildHistoryDrawer in the replacement.

  Widget _buildGlassButton(String text, bool isDark, Color primary) {
    if (text == 'exit') {
      return IconButton(
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
        color: isDark ? Colors.white70 : Colors.black54,
        onPressed: () => setState(() => _isScientific = false),
      );
    }

    bool isOperator = ['÷', '×', '-', '+', '='].contains(text);
    bool isAction = ['AC', '⌫', '%', 'sci'].contains(text);
    bool isSciFunc = _isScientific
        ? [
            'sin',
            'cos',
            'tan',
            'ln',
            'log',
            '^',
            'sqrt',
            '(',
            ')',
          ].contains(text)
        : false;

    Color? textColor;
    Color? btnColor;

    if (isOperator) {
      if (text == '=') {
        btnColor = primary;
        textColor = Colors.white;
      } else {
        textColor = isDark ? Colors.cyanAccent : primary;
      }
    } else if (isAction) {
      textColor = isDark ? Colors.orangeAccent : Colors.deepOrange;
    } else if (isSciFunc) {
      textColor = isDark ? Colors.white70 : Colors.black87;
    } else {
      textColor = isDark ? Colors.white : Colors.black87;
    }

    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            if (text == 'sci') {
              setState(() => _isScientific = true);
            } else if (text == 'sqrt') {
              _onPressed('sqrt(');
            } else if (['sin', 'cos', 'tan', 'log', 'ln'].contains(text)) {
              _onPressed('$text(');
            } else {
              _onPressed(text);
            }
          },
          overlayColor: WidgetStateProperty.all(primary.withValues(alpha: 0.1)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color:
                  btnColor ??
                  (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05)),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isOperator && text != '='
                    ? (isDark
                          ? Colors.cyanAccent.withValues(alpha: 0.3)
                          : primary.withValues(alpha: 0.3))
                    : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: text == '='
                  ? [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              text == 'sqrt' ? '√' : text,
              style: TextStyle(
                fontSize: _isScientific && text.length > 2 ? 18 : 26,
                fontWeight: isOperator || text == '='
                    ? FontWeight.bold
                    : FontWeight.w400,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryDrawer(bool isDark, Color primary) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: primary.withValues(alpha: 0.1)),
            child: Center(
              child: Text(
                'سجل العمليات',
                style: TextStyle(
                  color: isDark ? Colors.cyanAccent : primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          Expanded(
            child: _history.isEmpty
                ? Center(
                    child: Text(
                      'لا يوجد سجل بعد',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _historyScrollController,
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      return ListTile(
                        title: Text(
                          item['expression'] ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          '= ${item['result']}',
                          style: TextStyle(
                            fontSize: 18,
                            color: isDark ? Colors.cyanAccent : primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.copy,
                            size: 20,
                            color: isDark ? Colors.white38 : Colors.grey,
                          ),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(
                                text:
                                    '${item['expression']} = ${item['result']}',
                              ),
                            );
                            AppSnackBar.info(context, 'تم النسخ');
                          },
                        ),
                        onTap: () {
                          setState(() {
                            // Load history item
                            _expression = item['expression'] ?? '';
                            _previewResult = '';
                            _updateExpression(
                              _expression,
                            ); // Also update controller
                            Navigator.pop(context);
                          });
                        },
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('مسح السجل'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
              ),
              onPressed: () {
                setState(() => _history.clear());
                _saveHistory();
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- Expression Parser Classes ---
class Parser {
  int pos = -1, ch = -1;
  String str = '';

  Expression parse(String expression) {
    str = expression;
    pos = -1;
    nextChar();
    Expression x = parseExpression();
    if (pos < str.length) {
      throw Exception("Unexpected: ${String.fromCharCode(ch)}");
    }
    return x;
  }

  void nextChar() {
    ch = (++pos < str.length) ? str.codeUnitAt(pos) : -1;
  }

  bool eat(int charToEat) {
    while (ch == 32) {
      nextChar();
    }
    if (ch == charToEat) {
      nextChar();
      return true;
    }
    return false;
  }

  Expression parseExpression() {
    Expression x = parseTerm();
    while (true) {
      if (eat(43)) {
        // +
        x = Add(x, parseTerm());
      } else if (eat(45)) {
        // -
        x = Subtract(x, parseTerm());
      } else {
        return x;
      }
    }
  }

  Expression parseTerm() {
    Expression x = parseFactor();
    while (true) {
      if (eat(42)) {
        // *
        x = Multiply(x, parseFactor());
      } else if (eat(47)) {
        // /
        x = Divide(x, parseFactor());
      } else if (eat(37)) {
        // %
        x = Modulo(x, parseFactor());
      } else {
        return x;
      }
    }
  }

  Expression parseFactor() {
    while (ch == 32) {
      nextChar();
    }
    if (eat(43)) return parseFactor();
    if (eat(45)) return Negate(parseFactor());

    Expression x;
    int startPos = pos;
    if (eat(40)) {
      // (
      x = parseExpression();
      eat(41); // )
    } else if ((ch >= 48 && ch <= 57) || ch == 46) {
      // numbers
      while ((ch >= 48 && ch <= 57) || ch == 46) {
        nextChar();
      }
      x = Number(double.parse(str.substring(startPos, pos)));
    } else if (ch >= 97 && ch <= 122) {
      // functions
      while (ch >= 97 && ch <= 122) {
        nextChar();
      }
      String func = str.substring(startPos, pos);
      x = parseFactor();
      if (func == 'sqrt') {
        x = Sqrt(x);
      } else if (func == 'sin') {
        x = Sin(x);
      } else if (func == 'cos') {
        x = Cos(x);
      } else if (func == 'tan') {
        x = Tan(x);
      } else if (func == 'log') {
        x = Log(x);
      } else if (func == 'ln') {
        x = Ln(x);
      } else {
        throw Exception("Unknown function: $func");
      }
    } else {
      throw Exception("Unexpected: ${String.fromCharCode(ch)}");
    }

    if (eat(94)) x = Power(x, parseFactor()); // ^

    return x;
  }
}

abstract class Expression {
  double evaluate();
}

class Number extends Expression {
  final double value;
  Number(this.value);
  @override
  double evaluate() => value;
}

class Add extends Expression {
  final Expression left, right;
  Add(this.left, this.right);
  @override
  double evaluate() => left.evaluate() + right.evaluate();
}

class Subtract extends Expression {
  final Expression left, right;
  Subtract(this.left, this.right);
  @override
  double evaluate() => left.evaluate() - right.evaluate();
}

class Multiply extends Expression {
  final Expression left, right;
  Multiply(this.left, this.right);
  @override
  double evaluate() => left.evaluate() * right.evaluate();
}

class Divide extends Expression {
  final Expression left, right;
  Divide(this.left, this.right);
  @override
  double evaluate() => left.evaluate() / right.evaluate();
}

class Modulo extends Expression {
  final Expression left, right;
  Modulo(this.left, this.right);
  @override
  double evaluate() => left.evaluate() % right.evaluate();
}

class Power extends Expression {
  final Expression left, right;
  Power(this.left, this.right);
  @override
  double evaluate() => math.pow(left.evaluate(), right.evaluate()).toDouble();
}

class Negate extends Expression {
  final Expression left;
  Negate(this.left);
  @override
  double evaluate() => -left.evaluate();
}

class Sqrt extends Expression {
  final Expression val;
  Sqrt(this.val);
  @override
  double evaluate() => math.sqrt(val.evaluate());
}

class Sin extends Expression {
  final Expression val;
  Sin(this.val);
  @override
  double evaluate() => math.sin(val.evaluate());
}

class Cos extends Expression {
  final Expression val;
  Cos(this.val);
  @override
  double evaluate() => math.cos(val.evaluate());
}

class Tan extends Expression {
  final Expression val;
  Tan(this.val);
  @override
  double evaluate() => math.tan(val.evaluate());
}

class Log extends Expression {
  final Expression val;
  Log(this.val);
  @override
  double evaluate() => math.log(val.evaluate()) / math.ln10;
}

class Ln extends Expression {
  final Expression val;
  Ln(this.val);
  @override
  double evaluate() => math.log(val.evaluate());
}
