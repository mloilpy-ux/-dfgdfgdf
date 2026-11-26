package com.example.furry_content_hub

import android.app.WallpaperManager
import android.content.Intent
import android.content.ContentValues
import android.provider.MediaStore
import android.os.Environment
import android.graphics.BitmapFactory
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.furry.wallpaper/set"

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "takeSharedUrl" -> {
                    val text = if (intent?.action == Intent.ACTION_SEND) intent.getStringExtra(Intent.EXTRA_TEXT) else null
                    intent?.removeExtra(Intent.EXTRA_TEXT)
                    result.success(text)
                }
                "saveMedia" -> {
                    val path = call.argument<String>("path")
                    val name = call.argument<String>("name")
                    val mime = call.argument<String>("mime")
                    if (path == null || name == null || mime == null) { result.error("INPUT", "Missing media", null); return@setMethodCallHandler }
                    Thread {
                        try {
                            if (Build.VERSION.SDK_INT >= 29) {
                                val values = ContentValues().apply {
                                    put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                                    put(MediaStore.MediaColumns.MIME_TYPE, mime)
                                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/FurryHub")
                                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                                }
                                val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: error("Cannot create media")
                                try {
                                    contentResolver.openOutputStream(uri)!!.use { output -> File(path).inputStream().use { it.copyTo(output) } }
                                    values.clear()
                                    values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                                    contentResolver.update(uri, values, null, null)
                                } catch (e: Exception) { contentResolver.delete(uri, null, null); throw e }
                                runOnUiThread { result.success("Download/FurryHub/$name") }
                            } else {
                                val file = File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), name)
                                File(path).copyTo(file, overwrite = true)
                                runOnUiThread { result.success(file.absolutePath) }
                            }
                        } catch (e: Exception) { runOnUiThread { result.error("SAVE", e.message, null) } }
                    }.start()
                }
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
