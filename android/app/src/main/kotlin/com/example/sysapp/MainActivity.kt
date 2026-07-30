package com.example.sysapp

import android.content.Context
import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null
    private var pendingBluetoothPermissionResult: MethodChannel.Result? = null
    private var pendingWifiPermissionJoin: PendingWifiJoin? = null
    private var pendingWifiJoinResult: MethodChannel.Result? = null
    private var wifiNetworkCallback: ConnectivityManager.NetworkCallback? = null
    private var legacyWifiNetworkId: Int? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.gshub.sysapp/mdns",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquireMulticastLock" -> {
                    acquireMulticastLock()
                    result.success(null)
                }
                "releaseMulticastLock" -> {
                    releaseMulticastLock()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.gshub.sysapp/bluetooth_permissions",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "request" -> requestBluetoothPermissions(result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.gshub.sysapp/wifi",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "joinAP" -> requestJoinAP(call, result)
                "leaveAP" -> {
                    if (call.argument<Boolean>("forget") == true) {
                        forgetLegacyAPNetwork()
                    }
                    releaseAPNetwork()
                    result.success(null)
                }
                "openWiFiSettings" -> {
                    startActivity(Intent(Settings.ACTION_WIFI_SETTINGS))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestBluetoothPermissions(result: MethodChannel.Result) {
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        if (permissions.all { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }) {
            result.success(true)
            return
        }
        if (pendingBluetoothPermissionResult != null) {
            result.error("IN_PROGRESS", "Bluetooth permission request is already active", null)
            return
        }
        pendingBluetoothPermissionResult = result
        requestPermissions(permissions, bluetoothPermissionRequestCode)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == bluetoothPermissionRequestCode) {
            val granted = grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingBluetoothPermissionResult?.success(granted)
            pendingBluetoothPermissionResult = null
            return
        }
        if (requestCode == wifiPermissionRequestCode) {
            val pending = pendingWifiPermissionJoin
            pendingWifiPermissionJoin = null
            val granted = grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            if (!granted) {
                pending?.result?.error(
                    "WIFI_PERMISSION_DENIED",
                    "Wi-Fi permission was denied",
                    null,
                )
            } else if (pending != null) {
                joinAP(pending.ssid, pending.password, pending.timeoutMs, pending.result)
            }
        }
    }

    private fun requestJoinAP(call: MethodCall, result: MethodChannel.Result) {
        val ssid = call.argument<String>("ssid")?.trim().orEmpty()
        val password = call.argument<String>("password").orEmpty()
        val timeoutMs = call.argument<Int>("timeout_ms") ?: 30000
        if (ssid.isEmpty() || password.length !in 8..63) {
            result.error("INVALID_AP_CREDENTIALS", "Invalid AP SSID or password", null)
            return
        }
        if (pendingWifiJoinResult != null || pendingWifiPermissionJoin != null) {
            result.error("IN_PROGRESS", "A Wi-Fi join request is already active", null)
            return
        }
        val permissions = requiredWifiPermissions()
        if (permissions.any { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }) {
            pendingWifiPermissionJoin = PendingWifiJoin(ssid, password, timeoutMs, result)
            requestPermissions(permissions, wifiPermissionRequestCode)
            return
        }
        joinAP(ssid, password, timeoutMs, result)
    }

    private fun requiredWifiPermissions(): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            arrayOf(Manifest.permission.NEARBY_WIFI_DEVICES)
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    private fun joinAP(
        ssid: String,
        password: String,
        timeoutMs: Int,
        result: MethodChannel.Result,
    ) {
        releaseAPNetwork()
        pendingWifiJoinResult = result
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            joinAPWithSpecifier(ssid, password, timeoutMs)
        } else {
            joinLegacyAP(ssid, password, timeoutMs)
        }
    }

    private fun joinAPWithSpecifier(ssid: String, password: String, timeoutMs: Int) {
        val connectivity = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val specifier = WifiNetworkSpecifier.Builder()
            .setSsid(ssid)
            .setWpa2Passphrase(password)
            .build()
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .setNetworkSpecifier(specifier)
            .build()
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                runOnUiThread {
                    connectivity.bindProcessToNetwork(network)
                    finishWifiJoinSuccess()
                }
            }

            override fun onUnavailable() {
                runOnUiThread {
                    finishWifiJoinError(
                        "WIFI_JOIN_UNAVAILABLE",
                        "The robot hotspot was not available",
                    )
                }
            }

            override fun onLost(network: Network) {
                connectivity.bindProcessToNetwork(null)
            }
        }
        wifiNetworkCallback = callback
        try {
            connectivity.requestNetwork(request, callback, timeoutMs.coerceIn(5000, 60000))
        } catch (error: SecurityException) {
            finishWifiJoinError(
                "WIFI_NETWORK_PERMISSION_MISSING",
                "Android network access permission is missing",
            )
        } catch (error: Exception) {
            finishWifiJoinError("WIFI_JOIN_FAILED", error.message ?: "Unable to join hotspot")
        }
    }

    @Suppress("DEPRECATION")
    private fun joinLegacyAP(ssid: String, password: String, timeoutMs: Int) {
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        if (!wifi.isWifiEnabled) {
            wifi.isWifiEnabled = true
        }
        val quotedSSID = "\"$ssid\""
        val existing = wifi.configuredNetworks?.firstOrNull { it.SSID == quotedSSID }
        val networkId = existing?.networkId ?: wifi.addNetwork(
            WifiConfiguration().apply {
                SSID = quotedSSID
                preSharedKey = "\"$password\""
                allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA_PSK)
            },
        )
        if (networkId < 0 || !wifi.enableNetwork(networkId, true)) {
            finishWifiJoinError("WIFI_JOIN_FAILED", "Unable to enable robot hotspot")
            return
        }
        legacyWifiNetworkId = networkId
        wifi.reconnect()
        val deadline = SystemClock.elapsedRealtime() + timeoutMs.coerceIn(5000, 60000)
        mainHandler.post(object : Runnable {
            override fun run() {
                if (pendingWifiJoinResult == null) return
                val currentSSID = wifi.connectionInfo?.ssid?.trim('"')
                if (currentSSID == ssid) {
                    bindCurrentWifiNetwork()
                    finishWifiJoinSuccess()
                    return
                }
                if (SystemClock.elapsedRealtime() >= deadline) {
                    finishWifiJoinError("WIFI_JOIN_TIMEOUT", "Timed out joining robot hotspot")
                    return
                }
                mainHandler.postDelayed(this, 500)
            }
        })
    }

    private fun bindCurrentWifiNetwork() {
        val connectivity = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val wifiNetwork = connectivity.allNetworks.firstOrNull { network ->
            connectivity.getNetworkCapabilities(network)
                ?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
        }
        if (wifiNetwork != null) connectivity.bindProcessToNetwork(wifiNetwork)
    }

    private fun finishWifiJoinSuccess() {
        val result = pendingWifiJoinResult ?: return
        pendingWifiJoinResult = null
        result.success(true)
    }

    private fun finishWifiJoinError(code: String, message: String) {
        val result = pendingWifiJoinResult ?: return
        pendingWifiJoinResult = null
        releaseAPNetwork()
        result.error(code, message, null)
    }

    private fun releaseAPNetwork() {
        val connectivity = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        wifiNetworkCallback?.let {
            try {
                connectivity.unregisterNetworkCallback(it)
            } catch (_: Exception) {
                // The request may already have been released by Android.
            }
        }
        wifiNetworkCallback = null
        connectivity.bindProcessToNetwork(null)
    }

    @Suppress("DEPRECATION")
    private fun forgetLegacyAPNetwork() {
        val networkId = legacyWifiNetworkId ?: return
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        wifi.removeNetwork(networkId)
        wifi.saveConfiguration()
        legacyWifiNetworkId = null
    }

    private fun acquireMulticastLock() {
        if (multicastLock?.isHeld == true) return
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        multicastLock = wifi.createMulticastLock("gshub-mdns").apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun releaseMulticastLock() {
        multicastLock?.takeIf { it.isHeld }?.release()
        multicastLock = null
    }

    override fun onDestroy() {
        pendingBluetoothPermissionResult?.error(
            "ACTIVITY_DESTROYED",
            "Bluetooth permission request was interrupted",
            null,
        )
        pendingBluetoothPermissionResult = null
        pendingWifiPermissionJoin?.result?.error(
            "ACTIVITY_DESTROYED",
            "Wi-Fi permission request was interrupted",
            null,
        )
        pendingWifiPermissionJoin = null
        pendingWifiJoinResult?.error(
            "ACTIVITY_DESTROYED",
            "Wi-Fi join request was interrupted",
            null,
        )
        pendingWifiJoinResult = null
        releaseAPNetwork()
        releaseMulticastLock()
        super.onDestroy()
    }

    companion object {
        private const val bluetoothPermissionRequestCode = 4201
        private const val wifiPermissionRequestCode = 4202
    }

    private data class PendingWifiJoin(
        val ssid: String,
        val password: String,
        val timeoutMs: Int,
        val result: MethodChannel.Result,
    )
}
