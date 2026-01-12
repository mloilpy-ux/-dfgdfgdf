import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/source_provider.dart';
import '../models/content_source.dart';
import '../services/logger_service.dart';

class AddSourceScreen extends StatefulWidget {
  const AddSourceScreen({Key? key}) : super(key: key);

  @override
  State<AddSourceScreen> createState() => _AddSourceScreenState();
}

class _AddSourceScreenState extends State<AddSourceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  
  SourceType _selectedType = SourceType.reddit;
  bool _isNsfw = false;
  bool _isLoading = false;
  String? _errorMessage;

  final LoggerService _logger = LoggerService.instance;

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Добавить источник',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Выбор типа источника
            const Text(
              'Тип источника',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildTypeChip(SourceType.reddit)),
                const SizedBox(width: 8),
                Expanded(child: _buildTypeChip(SourceType.twitter)),
                const SizedBox(width: 8),
                Expanded(child: _buildTypeChip(SourceType.telegram)),
              ],
            ),

            const SizedBox(height: 24),

            // URL
            TextFormField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'URL источника',
                labelStyle: const TextStyle(color: Colors.grey),
                hintText: _getHintForType(),
                hintStyle: TextStyle(color: Colors.grey[700]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.link, color: Colors.orange),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите URL';
                }
                if (!_isValidUrl(value)) {
                  return 'Некорректный URL';
                }
                return null;
              },
              onChanged: (_) => _autoDetectName(),
            ),

            const SizedBox(height: 16),

            // Название
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Название',
                labelStyle: const TextStyle(color: Colors.grey),
                hintText: 'Например: r/furry_irl',
                hintStyle: TextStyle(color: Colors.grey[700]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.label, color: Colors.orange),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите название';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // NSFW switch
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: const Text(
                  'NSFW контент',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  '18+ материалы',
                  style: TextStyle(color: Colors.grey),
                ),
                value: _isNsfw,
                onChanged: (value) => setState(() => _isNsfw = value),
                activeColor: Colors.red,
                contentPadding: EdgeInsets.zero,
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Кнопка добавить
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _addSource,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.add),
              label: Text(
                _isLoading ? 'Добавление...' : 'Добавить источник',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(SourceType type) {
    final isSelected = _selectedType == type;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(
              type.icon,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 4),
            Text(
              type.displayName,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getHintForType() {
    switch (_selectedType) {
      case SourceType.reddit:
        return 'https://reddit.com/r/furry_irl';
      case SourceType.twitter:
        return 'https://twitter.com/username';
      case SourceType.telegram:
        return 'https://t.me/channel_name';
    }
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  void _autoDetectName() {
    final url = _urlController.text;
    
    if (url.contains('reddit.com/r/')) {
      final match = RegExp(r'reddit\.com/r/([^/]+)').firstMatch(url);
      if (match != null) {
        _nameController.text = 'r/${match.group(1)}';
      }
    } else if (url.contains('twitter.com/') || url.contains('x.com/')) {
      final match = RegExp(r'(?:twitter|x)\.com/([^/]+)').firstMatch(url);
      if (match != null) {
        _nameController.text = '@${match.group(1)}';
      }
    } else if (url.contains('t.me/')) {
      final match = RegExp(r't\.me/([^/]+)').firstMatch(url);
      if (match != null) {
        _nameController.text = match.group(1)!;
      }
    }
  }

  Future<void> _addSource() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final source = ContentSource(
        id: 'source_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text.trim(),
        url: _urlController.text.trim(),
        type: _selectedType,
        isActive: true,
        isNsfw: _isNsfw,
      );

      await context.read<SourceProvider>().addSource(source);
      
      _logger.log('✅ Добавлен источник: ${source.name}');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Добавлен: ${source.name}'),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка: $e';
        _isLoading = false;
      });
      _logger.log('❌ Ошибка добавления источника: $e', isError: true);
    }
  }
}
