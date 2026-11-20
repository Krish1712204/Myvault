package com.personalvault.myvault

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Prevent screen capture and task snapshots in system Recents switcher
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        BiometricKeyChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        PdfThumbnailChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        SystemChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }
}
