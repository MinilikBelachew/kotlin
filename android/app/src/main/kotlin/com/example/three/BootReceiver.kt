package com.example.three

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d("BootReceiver", "Device boot completed, starting service.")
            // Retrieve credentials from SharedPreferences
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val token = prefs.getString("flutter.token", null)
            val driverId = prefs.getInt("flutter.driverId", -1)

            if (!token.isNullOrEmpty() && driverId != -1) {
                val serviceIntent = Intent(context, LocationService::class.java).apply {
                    putExtra("token", token)
                    putExtra("driverId", driverId)
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }
        }
    }
}