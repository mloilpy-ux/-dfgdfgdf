import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/logger_service.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = LoggerService.instance.getLogs();

    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 Логи системы'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              LoggerService.instance.clearLogs();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(child: Text('Логи пусты'))
          : ListView.builder(
              reverse: true,
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[logs.length - 1 - index];
                return ListTile(
                  leading: Icon(
                    log.isError ? Icons.error : Icons.info,
                    color: log.isError ? Colors.red : Colors.blue,
                  ),
                  title: Text(log.message),
                  subtitle: Text(
                    DateFormat('HH:mm:ss').format(log.timestamp),
                  ),
                  dense: true,
                );
              },
            ),
    );
  }
}
