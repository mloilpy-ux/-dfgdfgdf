import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/content_source.dart';

class SourcesProvider extends ChangeNotifier {
  late final Box<ContentSource> box = Hive.box<ContentSource>('sources');
  List<ContentSource> get sources => box.values.toList();

  SourcesProvider() {
    if (box.isEmpty) _initDefaults();
  }

  void _initDefaults() {
    final defaults = [
      ContentSource(id: 'furry_irl', name: 'r/furry_irl', url: 'https://www.reddit.com/r/furry_irl/.json', type: SourceType.reddit),
      ContentSource(id
