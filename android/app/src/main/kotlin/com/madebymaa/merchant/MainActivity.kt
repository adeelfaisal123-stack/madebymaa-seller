package com.madebymaa.merchant

import android.content.Intent
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.content.pm.ApplicationInfo
import android.view.WindowManager
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream

class MainActivity : FlutterActivity() {
    private val pdfChannel = "com.madebymaa.merchant/pdf_download"

    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }
        if ((applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pdfChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "downloadPdf" -> {
                        val fileName = call.argument<String>("fileName") ?: "seller-agreement.pdf"
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null) {
                            result.error("INVALID", "Missing PDF bytes", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val saved = savePdfToDownloads(fileName, bytes)
                            if (saved != null) {
                                result.success(
                                    mapOf(
                                        "success" to true,
                                        "uri" to saved.first.toString(),
                                        "fileName" to saved.second,
                                    ),
                                )
                            } else {
                                result.error("SAVE_FAILED", "Could not save PDF to Downloads", null)
                            }
                        } catch (e: Exception) {
                            result.error("SAVE_FAILED", e.message, null)
                        }
                    }

                    "openPdf" -> {
                        val uriString = call.argument<String>("uri")
                        if (uriString.isNullOrBlank()) {
                            result.error("INVALID", "Missing PDF uri", null)
                            return@setMethodCallHandler
                        }
                        try {
                            openPdfUri(Uri.parse(uriString))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_FAILED", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun savePdfToDownloads(fileName: String, fileBytes: ByteArray): Pair<Uri, String>? {
        val resolver = applicationContext.contentResolver
        var adjustedFileName = fileName
        var fileNumber = 1

        var cursor: Cursor? = resolver.query(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            null,
            "${MediaStore.Downloads.DISPLAY_NAME} = ?",
            arrayOf(adjustedFileName),
            null,
        )

        while (cursor != null && cursor.moveToFirst()) {
            adjustedFileName =
                "${fileNameWithoutExtension(fileName)} ($fileNumber).${fileExtension(fileName)}"
            fileNumber++
            cursor.close()
            cursor = resolver.query(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                null,
                "${MediaStore.Downloads.DISPLAY_NAME} = ?",
                arrayOf(adjustedFileName),
                null,
            )
        }
        cursor?.close()

        val contentValues = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, adjustedFileName)
            put(MediaStore.Downloads.MIME_TYPE, "application/pdf")
            put(
                MediaStore.Downloads.RELATIVE_PATH,
                Environment.DIRECTORY_DOWNLOADS,
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
        }

        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
            ?: return null

        resolver.openOutputStream(uri)?.use { stream ->
            stream.write(fileBytes)
            stream.flush()
        } ?: return null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            contentValues.clear()
            contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, contentValues, null, null)
        }

        return Pair(uri, adjustedFileName)
    }

    private fun openPdfUri(uri: Uri) {
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/pdf")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
    }

    private fun fileNameWithoutExtension(fileName: String): String {
        return fileName.substringBeforeLast(".")
    }

    private fun fileExtension(fileName: String): String {
        return fileName.substringAfterLast(".")
    }
}
