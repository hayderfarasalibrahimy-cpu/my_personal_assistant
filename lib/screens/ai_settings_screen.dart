import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_key_service.dart';
import '../services/openrouter_service.dart';
import '../utils/app_snackbar.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final TextEditingController _newKeyController = TextEditingController();
  final TextEditingController _deepSeekKeyController = TextEditingController();
  final TextEditingController _mistralKeyController = TextEditingController();

  bool _isLoading = false;
  List<String> _openRouterKeys = [];
  List<String> _modelPriority = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    _openRouterKeys = await ApiKeyService.getOpenRouterKeys();

    final dsKey = await ApiKeyService.getDeepSeekKey();
    if (dsKey != null) {
      _deepSeekKeyController.text = dsKey;
    }

    final mKey = await ApiKeyService.getMistralKey();
    if (mKey != null) {
      _mistralKeyController.text = mKey;
    }

    _modelPriority = List.from(OpenRouterService.availableModels);

    setState(() => _isLoading = false);
  }

  Future<void> _addNewKey() async {
    final key = _newKeyController.text.trim();
    if (key.isEmpty) return;

    final success = await ApiKeyService.addOpenRouterKey(key);
    if (success) {
      _newKeyController.clear();
      await _loadSettings();
      if (mounted) {
        AppSnackBar.success(context, 'تم إضافة المفتاح بنجاح');
      }
    } else {
      if (mounted) {
        AppSnackBar.error(context, 'المفتاح غير صالح أو موجود مسبقاً');
      }
    }
  }

  Future<void> _removeKey(String key) async {
    final success = await ApiKeyService.removeOpenRouterKey(key);
    if (success) {
      await _loadSettings();
      if (mounted) {
        AppSnackBar.info(context, 'تم حذف المفتاح');
      }
    } else {
      if (mounted) {
        AppSnackBar.warning(context, 'لا يمكن حذف آخر مفتاح متبقي');
      }
    }
  }

  Future<void> _saveDirectKeys() async {
    await ApiKeyService.saveDeepSeekKey(_deepSeekKeyController.text.trim());
    await ApiKeyService.saveMistralKey(_mistralKeyController.text.trim());
    if (mounted) AppSnackBar.success(context, 'تم حفظ المفاتيح المباشرة');
  }

  Future<void> _verifyModels() async {
    // ... (Keep existing implementation of _verifyModels)
    final supportedModels = OpenRouterService.supportedModels;
    final ValueNotifier<Map<String, bool?>> statusNotifier = ValueNotifier({
      for (var m in supportedModels) m: null,
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('فحص النماذج'),
        content: SizedBox(
          width: double.maxFinite,
          child: ValueListenableBuilder<Map<String, bool?>>(
            valueListenable: statusNotifier,
            builder: (context, status, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('جاري التحقق من استجابة النماذج...'),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: supportedModels.length,
                      itemBuilder: (context, index) {
                        final name = supportedModels[index];
                        final s = status[name];
                        return ListTile(
                          dense: true,
                          title: Text(name),
                          leading: s == null
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  s ? Icons.check_circle : Icons.cancel,
                                  color: s ? Colors.green : Colors.red,
                                ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    final List<String> activeModelIds = [];
    for (final name in supportedModels) {
      final isWorking = await OpenRouterService.checkModelHealth(name);
      final newStatus = Map<String, bool?>.from(statusNotifier.value);
      newStatus[name] = isWorking;
      statusNotifier.value = newStatus;
      if (isWorking) {
        final id = OpenRouterService.modelMap[name];
        if (id != null) activeModelIds.add(id);
      }
    }

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) Navigator.pop(context);
    if (mounted) _showVerificationResults(statusNotifier.value, activeModelIds);
  }

  void _showVerificationResults(
    Map<String, bool?> status,
    List<String> availableIds,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نتائج الفحص'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: status.entries.map((e) {
              return ListTile(
                dense: true,
                title: Text(e.key),
                leading: Icon(
                  e.value == true ? Icons.check_circle : Icons.cancel,
                  color: e.value == true ? Colors.green : Colors.red,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (availableIds.isNotEmpty) {
                OpenRouterService.updateModels(availableIds);
                setState(() => _modelPriority = availableIds);
                AppSnackBar.success(context, 'تم تحديث قائمة النماذج النشطة');
              }
            },
            child: const Text('اعتماد النماذج'),
          ),
        ],
      ),
    );
  }

  void _showKeyInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('كيف تحصل على المفاتيح؟'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInstructionItem(
                '1. مفتاح Google Gemini',
                'https://aistudio.google.com/app/apikey',
                'مجاني وسريع، يدعم العربية بطلاقة.',
              ),
              const SizedBox(height: 16),
              _buildInstructionItem(
                '2. مفتاح OpenRouter',
                'https://openrouter.ai/keys',
                'يوفر وصولاً لنماذج مجانية متعددة.',
              ),
              const SizedBox(height: 16),
              _buildInstructionItem(
                '3. مفاتيح DeepSeek/Mistral (مباشر)',
                'https://platform.deepseek.com/',
                'أسرع وأكثر استقراراً من الوسيط.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('فهمت'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String title, String url, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => launchUrl(Uri.parse(url)),
          child: Text(
            url,
            style: const TextStyle(
              color: Colors.blue,
              decoration: TextDecoration.underline,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الذكاء الاصطناعي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showKeyInstructions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader(
                  'مفاتيح OpenRouter المتعددة',
                  Icons.vpn_key,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        if (_openRouterKeys.isEmpty ||
                            (_openRouterKeys.length == 1 &&
                                _openRouterKeys.first ==
                                    ApiKeyService.defaultOpenRouterKeys.first))
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'يتم استخدام المفتاح الافتراضي حالياً.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ..._openRouterKeys.map(
                          (key) => ListTile(
                            title: Text(
                              key.length > 20
                                  ? '${key.substring(0, 10)}...${key.substring(key.length - 10)}'
                                  : key,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => _removeKey(key),
                            ),
                            dense: true,
                          ),
                        ),
                        const Divider(),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newKeyController,
                                decoration: const InputDecoration(
                                  hintText: 'أضف مفتاح sk-or-v1- جديد',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle,
                                color: Colors.blue,
                              ),
                              onPressed: _addNewKey,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                _buildSectionHeader('المفاتيح المباشرة (Direct)', Icons.bolt),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _buildDirectKeyField(
                          'DeepSeek API Key',
                          _deepSeekKeyController,
                          'sk-...',
                        ),
                        const SizedBox(height: 12),
                        _buildDirectKeyField(
                          'Mistral API Key',
                          _mistralKeyController,
                          '...',
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _saveDirectKeys,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 40),
                          ),
                          child: const Text('حفظ المفاتيح المباشرة'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                _buildSectionHeader('النماذج والأولوية', Icons.model_training),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton.icon(
                          onPressed: _verifyModels,
                          icon: const Icon(Icons.refresh),
                          label: const Text('فحص النماذج'),
                        ),
                      ),
                      const Divider(),
                      ReorderableListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        header: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'اسحب لترتيب الأولوية',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (oldIndex < newIndex) newIndex -= 1;
                            final item = _modelPriority.removeAt(oldIndex);
                            _modelPriority.insert(newIndex, item);
                          });
                          OpenRouterService.updateModels(_modelPriority);
                        },
                        children: [
                          for (final model in _modelPriority)
                            ListTile(
                              key: ValueKey(model),
                              leading: const Icon(Icons.drag_handle, size: 20),
                              title: Text(
                                model.split('/').last,
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Text(
                                model.split('/').first,
                                style: const TextStyle(fontSize: 10),
                              ),
                              dense: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDirectKeyField(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            isDense: true,
            contentPadding: const EdgeInsets.all(10),
          ),
          style: const TextStyle(fontSize: 12),
          obscureText: true,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
