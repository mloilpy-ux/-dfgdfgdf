import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

Future<void> saveImage(String imageUrl) async {
  try {
    // Request permission
    if (await Permission.storage.request().isGranted) {
      final dir = await getTemporaryDirectory();
      final filename = imageUrl.split('/').last.replaceAll(RegExp(r'[^\w\.]'), '');
      final localPath = '${dir.path}/$filename';
      
      // Download
      await Dio().download(imageUrl, localPath);
      
      // Save to gallery
      final success = await Gal.putImage(localPath);
      
      if (success) {
        addLog('Saved $filename to gallery');
        // Show SnackBar via context
      } else {
        addLog('Failed to save to gallery');
      }
      
      // Cleanup
      await File(localPath).delete();
    }
  } catch (e) {
    addLog('Download error: $e');
  }
}
