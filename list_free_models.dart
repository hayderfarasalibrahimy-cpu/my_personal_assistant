import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

void main() async {
  final apiKey =
      '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';

  debugPrint('Fetching free models...');
  try {
    final response = await http.get(
      Uri.parse('https://openrouter.ai/api/v1/models'),
      headers: {'Authorization': 'Bearer $apiKey'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List models = data['data'];

      debugPrint('--- Free Models ---');
      for (var model in models) {
        final pricing = model['pricing'];
        if (pricing['prompt'] == '0' && pricing['completion'] == '0') {
          debugPrint(model['id']);
        }
      }
      debugPrint('-------------------');
    } else {
      debugPrint('Error: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('Error: $e');
  }
}
