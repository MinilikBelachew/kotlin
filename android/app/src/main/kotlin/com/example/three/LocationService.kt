package com.example.three
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import io.socket.client.IO
import io.socket.client.Socket
import org.json.JSONObject
import java.net.URISyntaxException

class LocationService : Service() {

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback
    private var socket: Socket? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val serverUrl = "http://192.168.119.177:4000" // Your server URL

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val token = intent?.getStringExtra("token")
        val driverId = intent?.getIntExtra("driverId", -1)

        if (token.isNullOrEmpty() || driverId == -1) {
            stopSelf()
            return START_NOT_STICKY
        }

        // Acquire a wake lock to keep the CPU running
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "LocationService::Wakelock")
        wakeLock?.acquire(10*60*1000L /*10 minutes*/)

        startForegroundService()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        startLocationUpdates()
        connectToSocket(token, driverId!!)

        return START_STICKY
    }

    private fun startForegroundService() {
        val channelId = "location_service_channel"
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Location Service", NotificationManager.IMPORTANCE_LOW)
            notificationManager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Driver App is Running")
            .setContentText("Actively tracking location.")
            .setSmallIcon(R.mipmap.ic_launcher) // Ensure you have this icon
            .setOngoing(true)
            .build()

        startForeground(1, notification)
    }

    private fun startLocationUpdates() {
        val locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 10000) // 10 seconds
            .setMinUpdateIntervalMillis(5000) // 5 seconds
            .build()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                locationResult.lastLocation?.let { location ->
                    sendLocationUpdate(location.latitude, location.longitude)
                }
            }
        }

        try {

            fusedLocationClient.requestLocationUpdates(locationRequest, locationCallback, mainLooper)
        } catch (e: SecurityException) {
            Log.e("LocationService", "Location permission not granted.", e)
            stopSelf()
        }
    }

    private fun connectToSocket(token: String, driverId: Int) {
        try {
            val opts = IO.Options().apply {
                transports = arrayOf("websocket")
                auth = mapOf("token" to token)
            }
            socket = IO.socket(serverUrl, opts)

            socket?.on(Socket.EVENT_CONNECT) { Log.d("LocationService", "Socket Connected") }
            socket?.on(Socket.EVENT_DISCONNECT) { Log.d("LocationService", "Socket Disconnected") }
            socket?.on(Socket.EVENT_CONNECT_ERROR) { args ->
                Log.e("LocationService", "Socket Connection Error: ${args[0]}")
            }
            socket?.connect()
        } catch (e: URISyntaxException) {
            Log.e("LocationService", "Socket URI Syntax Exception.", e)
        }
    }

    private fun sendLocationUpdate(lat: Double, lng: Double) {
        if (socket?.connected() == true) {
            val locationData = JSONObject().apply {
                put("lat", lat)
                put("lng", lng)
                // You can add driverId and other details here if needed
            }
            socket?.emit("driverLocation", locationData)
            Log.d("LocationService", "Location update sent.")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        fusedLocationClient.removeLocationUpdates(locationCallback)
        socket?.disconnect()
        wakeLock?.release() // Release the wake lock
    }

    override fun onBind(intent: Intent?): IBinder? = null
}