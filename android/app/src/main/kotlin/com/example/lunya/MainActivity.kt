package com.example.furry_content_hub

import android.app.WallpaperManager
import android.graphics.BitmapFactory
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.furry.wallpaper/set"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setWallpaper" -> {
                    val imagePath = call.argument<String>("path")
                    if (imagePath != null) {
                        try {
                            val wallpaperManager = WallpaperManager.getInstance(applicationContext)
                            val bitmap = BitmapFactory.decodeFile(imagePath)
                            
                            if (bitmap != null) {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                    // Android 7.0+ - можно выбрать главный экран или экран блокировки
                                    wallpaperManager.setBitmap(bitmap, null, true, WallpaperManager.FLAG_SYSTEM)
                                } else {
                                    wallpaperManager.setBitmap(bitmap)
                                }
                                result.success("Обои установлены!")
                            } else {
                                result.error("BITMAP_ERROR", "Не удалось загрузить изображение", null)
                            }
                        } catch (e: Exception) {
                            result.error("WALLPAPER_ERROR", e.message, null)
                        }
                    } else {
                        result.error("PATH_ERROR", "Путь к изображению не указан", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
