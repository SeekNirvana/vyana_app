package com.seeknirvana.vyana

import android.Manifest
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import com.yucheng.ycbtsdk.YCBTClient
import com.yucheng.ycbtsdk.response.BleDataResponse
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingStorageResult: MethodChannel.Result? = null
    private var solanaMobileWalletHandler: SolanaMobileWalletHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        solanaMobileWalletHandler = SolanaMobileWalletHandler(this).also {
            it.register(flutterEngine)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestBleScanAccess" -> requestBleScanAccess(result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensureAccess" -> ensureAppStorageAccess(result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RING_DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setDeviceName" -> setDeviceName(call.argument<String>("name"), result)
                    "isBluetoothEnabled" -> isBluetoothEnabled(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestBleScanAccess(result: MethodChannel.Result) {
        val missing = requiredBlePermissions().filter {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
            } else {
                false
            }
        }

        if (missing.isEmpty()) {
            result.success(scanAccessPayload(emptyList()))
            return
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success(scanAccessPayload(emptyList()))
            return
        }

        pendingPermissionResult?.success(scanAccessPayload(missing))
        pendingPermissionResult = result
        requestPermissions(missing.toTypedArray(), BLE_PERMISSION_REQUEST)
    }

    private fun isBluetoothEnabled(result: MethodChannel.Result) {
        try {
            val manager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            result.success(manager?.adapter?.isEnabled == true)
        } catch (_: SecurityException) {
            result.success(null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            BLE_PERMISSION_REQUEST -> {
                val stillMissing = permissions.filterIndexed { index, _ ->
                    grantResults.getOrNull(index) != PackageManager.PERMISSION_GRANTED
                }

                pendingPermissionResult?.success(scanAccessPayload(stillMissing))
                pendingPermissionResult = null
            }
            STORAGE_PERMISSION_REQUEST -> {
                val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
                pendingStorageResult?.success(
                    storageAccessPayload(
                        granted = granted,
                        reason = if (granted) {
                            null
                        } else {
                            "Storage permission denied. Vyana cannot save your data."
                        },
                    ),
                )
                pendingStorageResult = null
            }
        }
    }

    private fun ensureAppStorageAccess(result: MethodChannel.Result) {
        val externalDir = getExternalFilesDir(null)
        if (externalDir == null) {
            result.success(
                storageAccessPayload(
                    granted = false,
                    reason = "External app storage is unavailable on this device.",
                ),
            )
            return
        }

        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
            if (checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                != PackageManager.PERMISSION_GRANTED
            ) {
                pendingStorageResult = result
                requestPermissions(
                    arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                    STORAGE_PERMISSION_REQUEST,
                )
                return
            }
        }

        result.success(storageAccessPayload(granted = true, reason = null))
    }

    private fun storageAccessPayload(
        granted: Boolean,
        reason: String?,
    ): Map<String, Any?> {
        return mapOf(
            "granted" to granted,
            "reason" to reason,
        )
    }

    private fun requiredBlePermissions(): List<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            listOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT
            )
        } else {
            listOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            )
        }
    }

    private fun scanAccessPayload(missingPermissions: List<String>): Map<String, Any> {
        val locationEnabled = isLocationEnabled()
        return mapOf(
            "granted" to (missingPermissions.isEmpty() && locationEnabled),
            "permissionsGranted" to missingPermissions.isEmpty(),
            "locationEnabled" to locationEnabled,
            "missingPermissions" to missingPermissions
        )
    }

    private fun isLocationEnabled(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) return true

        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return try {
            locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        } catch (_: Exception) {
            false
        }
    }

    private fun setDeviceName(name: String?, result: MethodChannel.Result) {
        val cleanName = name?.trim()?.replace(Regex("\\s+"), " ").orEmpty()
        if (cleanName.isEmpty()) {
            result.success(
                mapOf(
                    "statusCode" to PLUGIN_STATE_FAILED,
                    "message" to "Ring name is required"
                )
            )
            return
        }

        YCBTClient.settingDeviceName(
            cleanName,
            BleDataResponse { code, _, payload ->
                runOnUiThread {
                    result.success(
                        mapOf(
                            "statusCode" to pluginStatusCode(code),
                            "sdkCode" to code,
                            "message" to deviceNameMessage(code),
                            "data" to (payload ?: emptyMap<String, Any>())
                        )
                    )
                }
            }
        )
    }

    private fun pluginStatusCode(code: Int): Int {
        return when (code and 0xFF) {
            0 -> PLUGIN_STATE_SUCCEED
            0xFC, 0xFD -> PLUGIN_STATE_UNAVAILABLE
            else -> PLUGIN_STATE_FAILED
        }
    }

    private fun deviceNameMessage(code: Int): String {
        return when (code and 0xFF) {
            0 -> "Ring accepted name change"
            0xFC, 0xFD -> "Ring name change is unavailable"
            else -> "Ring rejected name change"
        }
    }

    companion object {
        private const val CHANNEL = "vyana/permissions"
        private const val STORAGE_CHANNEL = "vyana/storage"
        private const val RING_DEVICE_CHANNEL = "vyana/ring_device"
        private const val BLE_PERMISSION_REQUEST = 2407
        private const val STORAGE_PERMISSION_REQUEST = 2408
        private const val PLUGIN_STATE_SUCCEED = 0
        private const val PLUGIN_STATE_FAILED = 1
        private const val PLUGIN_STATE_UNAVAILABLE = 2
    }
}
