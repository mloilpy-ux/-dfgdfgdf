import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/background_sync.dart';
import '../services/logger_service.dart';

Future<void> showGestures(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Свайпы и просмотр'),
    content: const Text(
      'В разделах обоев, GIF и видео:\n\n← / → — следующие / предыдущие обои\n↑ — добавить или убрать из избранного\n↓ — скачать изображение\nДвойное касание — открыть увеличенный просмотр\n\nВ увеличенном просмотре: разведите пальцы для увеличения, сведите для уменьшения. Перетаскивайте увеличенное медиа одним пальцем.\n\nВ миксах: свайп вверх — следующий материал.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Понятно'),
      ),
    ],
  ),
);

class ExperienceScreen extends StatefulWidget {
  const ExperienceScreen({super.key});
  @override
  State<ExperienceScreen> createState() => _ExperienceScreenState();
}

class _ExperienceScreenState extends State<ExperienceScreen> {
  bool enabled = true;
  String last = 'Ещё не запускалось';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (mounted)
      setState(() {
        enabled = prefs.getBool('backgroundSync') ?? true;
        last = prefs.getString('lastBackgroundSync') ?? last;
      });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Загрузка и управление')),
    body: ListView(
      children: [
        SwitchListTile(
          title: const Text('Фоновая загрузка по Wi-Fi'),
          subtitle: const Text(
            'Порциями, примерно раз в 30 минут. Android может отложить запуск для экономии батареи.',
          ),
          value: enabled,
          onChanged: (value) async {
            try {
              await BackgroundSync.configure(value);
              await (await SharedPreferences.getInstance()).setBool(
                'backgroundSync',
                value,
              );
              if (mounted) setState(() => enabled = value);
            } catch (e) {
              LoggerService.instance.log(
                'Настройка фоновой загрузки: $e',
                isError: true,
              );
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Не удалось изменить фоновую загрузку'),
                  ),
                );
            }
          },
        ),
        ListTile(
          title: const Text('Последнее фоновое обновление'),
          subtitle: Text(last),
        ),
        const ListTile(
          title: Text('Доступ к источникам'),
          subtitle: Text(
            'HTML загружается без API. Страницы с JavaScript, входом или проверкой сайта могут потребовать браузер. В фоне предзагружаются картинки, GIF и небольшие видео: до 6 МБ на файл, до 24 МБ сохранённых медиа за запуск. Крупные файлы — при просмотре.',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.swipe),
          title: const Text('Как работают свайпы'),
          onTap: () => showGestures(context),
        ),
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: const Text('Отчёты приложения'),
          subtitle: Text(
            LoggerService.instance.path ?? 'Файл журнала ещё не открыт',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.ios_share),
          title: const Text('Экспорт отчётов'),
          subtitle: const Text(
            'Выберите приложение или папку в системном меню',
          ),
          onTap: () async {
            try {
              await LoggerService.instance.export();
            } catch (e) {
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Не удалось экспортировать отчёт'),
                  ),
                );
            }
          },
        ),
        const ListTile(
          subtitle: Text(
            'Отчёты: события приложения, загрузки, ошибки и состояние Android. Хранятся 7 дней, до 2 МБ на файл. Пароли, cookies и токены не записываются. Системные журналы других приложений недоступны.\n\nФильтр 18+ учитывает метки источника и публикации; это не распознавание содержимого картинки.',
          ),
        ),
      ],
    ),
  );
}
