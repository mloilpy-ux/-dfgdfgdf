import 'package:http/http.dart' as http;

class SourceFailure implements Exception {
  const SourceFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

Future<http.Response> fetchSource(
  http.Client client,
  Uri uri, {
  required String service,
  Map<String, String> headers = const {},
}) async {
  final request = http.Request('GET', uri)
    ..headers.addAll(headers)
    ..followRedirects = !headers.containsKey('Authorization');
  final response = await _read(
    client,
    request,
  ).timeout(const Duration(seconds: 18));
  if (response.statusCode == 200) return response;
  throw SourceFailure(switch (response.statusCode) {
    401 => '$service отклонил токен API',
    402 => '$service требует доступный тариф или баланс API',
    403 => '$service ограничил доступ к источнику',
    404 => '$service: источник не найден или закрыт',
    429 => '$service ограничил частоту запросов. Попробуйте позже',
    _ => '$service: ошибка HTTP ${response.statusCode}',
  });
}

Future<http.Response> _read(http.Client client, http.Request request) async {
  return http.Response.fromStream(await client.send(request));
}

Uri? mediaUri(String? input, [Uri? base]) {
  if (input == null || input.trim().isEmpty) return null;
  final value = input.trim().replaceAll('&amp;', '&');
  final parsed = Uri.tryParse(value);
  if (parsed == null) return null;
  final uri = base?.resolveUri(parsed) ?? parsed;
  if (uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      !{'https', 'http'}.contains(uri.scheme))
    return null;
  return uri;
}
