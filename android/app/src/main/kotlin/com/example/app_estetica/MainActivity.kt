package com.example.app_estetica

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "app_estetica/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "shareFileToWhatsApp" -> {
                    val path = call.argument<String>("path")
                    val caption = call.argument<String>("caption")
                    val targetPackage = call.argument<String>("package")
                    val phone = call.argument<String>("phone")
                    if (path == null) {
                        result.error("NO_PATH", "No file path provided", null)
                        return@setMethodCallHandler
                    }
                    val success = shareFileToWhatsApp(path, caption ?: "", targetPackage, phone)
                    result.success(success)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun shareFileToWhatsApp(path: String, caption: String, targetPackage: String?, phone: String?): Boolean {
        return try {
            val file = File(path)
            val uri: Uri = FileProvider.getUriForFile(this, "${applicationContext.packageName}.fileprovider", file)
            val intent = Intent(Intent.ACTION_SEND)
            intent.type = contentResolver.getType(uri) ?: "*/*"
            intent.putExtra(Intent.EXTRA_STREAM, uri)
            intent.putExtra(Intent.EXTRA_TEXT, caption)
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

            // Si se especificó un package (com.whatsapp o com.whatsapp.w4b) lo usamos
            if (targetPackage != null && (targetPackage == "com.whatsapp" || targetPackage == "com.whatsapp.w4b")) {
                intent.setPackage(targetPackage)
            }

            // Si se pasó un número, intentar enviar directamente al jid
            if (phone != null && phone.isNotEmpty()) {
                // whatsapp expects jid like 59171234567@s.whatsapp.net
                val jid = if (phone.contains("@")) phone else "$phone@s.whatsapp.net"
                intent.putExtra("jid", jid)
            }

            startActivity(intent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}
