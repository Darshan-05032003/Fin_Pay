package com.finpay.app

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter engine and the `fin_pay/screen_protector` channel.
 *
 * `FlutterFragmentActivity` (not `FlutterActivity`) because `local_auth`
 * needs a `FragmentActivity` to show the biometric prompt.
 *
 * Channel methods:
 *  - `enable`: adds `FLAG_SECURE`, so screenshots and screen recording are
 *    blocked and the recents thumbnail is blank.
 *  - `disable`: clears the flag.
 */
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SCREEN_PROTECTOR_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> {
                    window.setFlags(
                        WindowManager.LayoutParams.FLAG_SECURE,
                        WindowManager.LayoutParams.FLAG_SECURE,
                    )
                    result.success(null)
                }
                "disable" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private companion object {
        const val SCREEN_PROTECTOR_CHANNEL = "fin_pay/screen_protector"
    }
}
