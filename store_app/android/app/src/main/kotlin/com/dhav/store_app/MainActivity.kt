package com.dhav.store_app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.dhav.store_app/incoming_order"
    }

    private var methodChannel: MethodChannel? = null

    // Cached on every incoming intent. Dart pulls and clears via the
    // `consumePendingOrder` method-channel call once its navigator is ready.
    @Volatile
    private var pendingOrderId: String? = null
    @Volatile
    private var pendingType: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureIntent(intent)
        // If Dart is already attached (app was backgrounded, now coming
        // forward), notify it immediately so it can pull.
        methodChannel?.invokeMethod("pendingOrderAvailable", null)
    }

    private fun captureIntent(intent: Intent?) {
        val orderId = intent?.getStringExtra(DhavMessagingService.EXTRA_ORDER_ID)
        val type = intent?.getStringExtra(DhavMessagingService.EXTRA_NOTIF_TYPE)
        if (orderId != null) {
            pendingOrderId = orderId
            pendingType = type
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        )
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePendingOrder" -> {
                    val orderId = pendingOrderId
                    val type = pendingType
                    pendingOrderId = null
                    pendingType = null
                    if (orderId == null) {
                        result.success(null)
                    } else {
                        result.success(
                            mapOf("order_id" to orderId, "type" to type),
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
