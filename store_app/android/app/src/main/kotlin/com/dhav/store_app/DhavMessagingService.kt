package com.dhav.store_app

import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * Custom FCM service that, in addition to the normal Flutter background
 * dispatch, FORCES MainActivity to the foreground when a new-order /
 * delivery-assignment message arrives.
 *
 * Why: Android's full-screen intent only auto-launches the activity when the
 * device is locked. When the screen is on and the user is in another app,
 * Android downgrades the full-screen intent to a heads-up notification. To
 * get Uber/Ola-style "popup over any app" behavior we have to call
 * startActivity() ourselves — which is only allowed from a background context
 * if the app holds SYSTEM_ALERT_WINDOW (canDrawOverlays).
 */
class DhavMessagingService : FlutterFirebaseMessagingService() {

    companion object {
        private const val TAG = "DhavMessagingService"
        const val EXTRA_ORDER_ID = "dhav_order_id"
        const val EXTRA_NOTIF_TYPE = "dhav_notification_type"
    }

    override fun onMessageReceived(message: RemoteMessage) {
        // Always let the Flutter plugin handle the message first — this
        // dispatches to the Dart background handler (which shows the
        // notification with full-screen intent + sound).
        super.onMessageReceived(message)

        val type = message.data["type"] ?: return
        if (type != "new_order" && type != "delivery_assigned") return

        val orderId = message.data["order_id"] ?: return

        // Background activity starts on Android 10+ require canDrawOverlays.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            !Settings.canDrawOverlays(this)
        ) {
            Log.w(TAG, "SYSTEM_ALERT_WINDOW not granted — falling back to " +
                    "full-screen intent notification only.")
            return
        }

        try {
            val launch = packageManager.getLaunchIntentForPackage(packageName)
            if (launch == null) {
                Log.e(TAG, "No launch intent for package $packageName")
                return
            }
            launch.flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            launch.putExtra(EXTRA_ORDER_ID, orderId)
            launch.putExtra(EXTRA_NOTIF_TYPE, type)
            startActivity(launch)
            Log.i(TAG, "Forced MainActivity to foreground for $type orderId=$orderId")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch MainActivity: ${e.message}", e)
        }
    }
}
