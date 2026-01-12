import 'package:nsfw_detector_flutter/nsfw_detector_flutter.dart';
import 'package:http/http.dart' as http;
import 'logger_service.dart';

class NsfwDetectorService {
  static final NsfwDetectorService instance = NsfwDetectorService._init();
  NsfwDetector? _detector;
  final LoggerService _logger = LoggerService.instance;

  NsfwDetectorService._init();

  Future<void> initialize() async {
    _detector = await NsfwDetector.load(threshold: 0.6);
    _logger.log('🔞 NSFW детектор инициализирован');
  }

  Future<bool> isNsfw(String imageUrl) async {
    if (_detector == null) await initialize();
    
    try {
      _logger.log('🔍 Проверка NSFW: $imageUrl');
      
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        _logger.log('❌ Не удалось загрузить изображение');
        return false;
      }

      final result = await _detector!.detectNSFWFromBytes(response.bodyBytes);
      
      if (result == null) {
        _logger.log('⚠️ Результат детекции null');
        return false;
      }

      _logger.log('📊 NSFW Score: ${result.score.toStringAsFixed(2)} - ${result.isNsfw ? "NSFW" : "SFW"}');
      
      return result.isNsfw;
      
    } catch (e) {
      _logger.log('💥 Ошибка детекции NSFW: $e', isError: true);
      return false;
    }
  }
}
