import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/logger_provider.dart';
import 'dart:async';
import '../services/logger_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        context.read<LoggerProvider>().refresh();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 Детальные логи'),
        actions: [
          IconButton(
            tooltip: 'Экспорт отчётов',
            icon: const Icon(Icons.ios_share),
            onPressed: () async {
              try {
                await LoggerService.instance.export();
              } catch (_) {}
            },
          ),
          Consumer<LoggerProvider>(
            builder: (context, provider, _) => TextButton.icon(
              onPressed: provider.clearLogs,
              icon: const Icon(Icons.clear_all, color: Colors.white),
              label: const Text(
                'Очистить',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<LoggerProvider>(
        builder: (context, provider, _) {
          final logs = provider.logs;

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.deepOrange.withOpacity(0.1),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    Text(
                      'Всего записей: ${logs.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: logs.isEmpty
                    ? const Center(
                        child: Text(
                          'Логи пусты\nДействия будут записываться здесь',
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[logs.length - 1 - index];
                          final isError = log.contains('ERROR');

                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isError
                                  ? Colors.red.withOpacity(0.1)
                                  : Colors.green.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isError
                                    ? Colors.red.shade200
                                    : Colors.green.shade200,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              log,
                              style: TextStyle(
                                fontSize: 12,
                                color: isError
                                    ? Colors.red.shade200
                                    : Colors.white70,
                                fontFamily: 'monospace',
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
