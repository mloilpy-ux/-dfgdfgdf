import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/logger_provider.dart';
import '../services/logger_service.dart';
import 'dart:async';

class LogsTab extends StatefulWidget {
  const LogsTab({super.key});

  @override
  State<LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<LogsTab> {
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
    return Consumer<LoggerProvider>(
      builder: (context, provider, _) {
        final logs = provider.logs;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Text('Логов: ${logs.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: provider.clearLogs,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Очистить'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: logs.isEmpty
                  ? const Center(child: Text('Логи пусты'))
                  : ListView.builder(
                      reverse: true,
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[logs.length - 1 - index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            log,
                            style: TextStyle(
                              fontSize: 12,
                              color: log.contains('❌') ? Colors.red : Colors.black87,
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
    );
  }
}
