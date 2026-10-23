package sn.dialawtv.dialaw_tv

import android.annotation.SuppressLint
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Identifiant de l'appareil pour l'essai gratuit et l'abonnement. ANDROID_ID est
    // propre à l'appli (clé de signature) et survit à une réinstallation.
    @SuppressLint("HardwareIds")
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sn.dialawtv/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "deviceId") {
                    result.success(
                        Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                    )
                } else {
                    result.notImplemented()
                }
            }
    }
}
