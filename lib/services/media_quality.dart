/// Prefer actual Reddit original URLs over previews of the same asset.
/// Never invent an original URL or strip the signature from a preview.
String preferredMediaUrl(String current, String incoming) {
  final old = Uri.tryParse(current);
  final next = Uri.tryParse(incoming);
  const hosts = {'i.redd.it', 'preview.redd.it'};
  if (old == null || next == null ||
      old.scheme != 'https' || next.scheme != 'https' ||
      !hosts.contains(old.host) || !hosts.contains(next.host) ||
      old.path != next.path) return incoming;
  if (old.host == 'i.redd.it' && next.host == 'preview.redd.it') return current;
  if (next.host == 'i.redd.it') return incoming;
  final oldWidth = int.tryParse(old.queryParameters['width'] ?? '') ?? 0;
  final newWidth = int.tryParse(next.queryParameters['width'] ?? '') ?? 0;
  return oldWidth > newWidth ? current : incoming;
}
