package `in`.co.sail.bsl.crm3.bafops

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.Uri
import android.os.Build
import android.system.Os
import android.system.OsConstants
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var criticalAlarmMethodChannel: MethodChannel? = null
    private var networkAccessSink: EventChannel.EventSink? = null
    private var networkAccessCallback: ConnectivityManager.NetworkCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ensureCriticalAlarmChannel()
        configureCriticalAlarmChannel(flutterEngine)
        configureNetworkAccessChannel(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            RECOVERY_STORAGE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            val pathArgument: String
            val expectedDirectory: Boolean
            when (call.method) {
                "syncDirectory" -> {
                    pathArgument = "directoryPath"
                    expectedDirectory = true
                }
                "syncFile" -> {
                    pathArgument = "filePath"
                    expectedDirectory = false
                }
                else -> {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
            }

            val rawPath = call.argument<String>(pathArgument)
            if (rawPath.isNullOrBlank()) {
                result.error(
                    "storage-path-invalid",
                    "An application-private recovery storage path is required.",
                    null,
                )
                return@setMethodCallHandler
            }

            try {
                val entity = File(rawPath).canonicalFile
                val appDataDirectory = File(applicationInfo.dataDir).canonicalFile
                val insideAppData = entity.path == appDataDirectory.path ||
                    entity.path.startsWith(appDataDirectory.path + File.separator)
                val expectedEntityType =
                    (expectedDirectory && entity.isDirectory) ||
                        (!expectedDirectory && entity.isFile)
                if (!insideAppData || !expectedEntityType) {
                    result.error(
                        "storage-path-rejected",
                        "Only an existing application-private recovery storage entity can be synchronized.",
                        null,
                    )
                    return@setMethodCallHandler
                }

                val openFlags = if (expectedDirectory) {
                    OsConstants.O_RDONLY
                } else {
                    OsConstants.O_RDWR
                }
                val descriptor = Os.open(
                    entity.path,
                    openFlags,
                    0,
                )
                try {
                    Os.fsync(descriptor)
                } finally {
                    Os.close(descriptor)
                }
                result.success(true)
            } catch (error: Exception) {
                result.error(
                    "storage-sync-failed",
                    error.message ?: "The recovery storage entity could not be synchronized.",
                    null,
                )
            }
        }
    }

    private fun configureCriticalAlarmChannel(flutterEngine: FlutterEngine) {
        criticalAlarmMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CRITICAL_ALARM_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                "consumeOpenedAlarmId" -> {
                    val alarmId = intent?.getStringExtra(CRITICAL_ALARM_ID_EXTRA)
                    intent?.removeExtra(CRITICAL_ALARM_ID_EXTRA)
                    result.success(alarmId)
                }
                "showActiveNotification" -> {
                    val alarmId = call.argument<String>("alarmId")
                    val title = call.argument<String>("title")
                    val body = call.argument<String>("body")
                    if (alarmId.isNullOrBlank() || title.isNullOrBlank() || body.isNullOrBlank()) {
                        result.error(
                            "critical-alarm-notification-invalid",
                            "Alarm ID, title and body are required.",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
                            !notificationManager().areNotificationsEnabled()
                        ) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        showCriticalAlarmNotification(alarmId, title, body)
                        result.success(true)
                    } catch (error: Exception) {
                        result.error(
                            "critical-alarm-notification-failed",
                            error.message ?: "The critical alarm notification could not be shown.",
                            null,
                        )
                    }
                }
                "cancelNotification" -> {
                    val alarmId = call.argument<String>("alarmId")
                    if (alarmId.isNullOrBlank()) {
                        result.error(
                            "critical-alarm-id-invalid",
                            "An alarm ID is required.",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    notificationManager().cancel(
                        notificationTag(alarmId),
                        CRITICAL_NOTIFICATION_ID,
                    )
                    result.success(null)
                }
                "reconcileActiveNotifications" -> {
                    val rawIds = call.argument<List<*>>("ringingAlarmIds")
                    val ringingAlarmIds = rawIds?.mapNotNull { value ->
                        (value as? String)?.trim()?.takeIf { alarmId ->
                            alarmId.isNotEmpty() &&
                                alarmId.length <= 160 &&
                                alarmId != "." &&
                                alarmId != ".." &&
                                !alarmId.contains("/")
                        }
                    }
                    if (rawIds == null || rawIds.size > 500 ||
                        ringingAlarmIds == null || ringingAlarmIds.size != rawIds.size ||
                        ringingAlarmIds.toSet().size != ringingAlarmIds.size
                    ) {
                        result.error(
                            "critical-alarm-active-set-invalid",
                            "The verified active alarm set is invalid.",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    try {
                        val manager = notificationManager()
                        var cancelled = 0
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val ringingTags = ringingAlarmIds
                                .map(::notificationTag)
                                .toSet()
                            for (notification in manager.activeNotifications) {
                                val tag = notification.tag ?: continue
                                if (tag.startsWith(CRITICAL_NOTIFICATION_TAG_PREFIX) &&
                                    !ringingTags.contains(tag)
                                ) {
                                    manager.cancel(tag, notification.id)
                                    cancelled += 1
                                }
                            }
                        }
                        result.success(cancelled)
                    } catch (error: Exception) {
                        result.error(
                            "critical-alarm-reconciliation-failed",
                            error.message ?: "Critical alarm notifications could not be reconciled.",
                            null,
                        )
                    }
                }
                "openDialer" -> {
                    val dialValue = call.argument<String>("dialValue")?.trim()
                    if (dialValue == null || !DIAL_VALUE.matches(dialValue)) {
                        result.error(
                            "critical-alarm-contact-invalid",
                            "The approved contact number is invalid.",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    try {
                        startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$dialValue")))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error(
                            "dialler-unavailable",
                            error.message ?: "The device dialler could not be opened.",
                            null,
                        )
                    }
                }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val alarmId = intent.getStringExtra(CRITICAL_ALARM_ID_EXTRA)
        if (!alarmId.isNullOrBlank()) {
            criticalAlarmMethodChannel?.invokeMethod(
                "criticalAlarmOpened",
                mapOf("alarmId" to alarmId),
            )
        }
    }

    private fun notificationManager(): NotificationManager =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun ensureCriticalAlarmChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val sound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .build()
        val channel = NotificationChannel(
            CRITICAL_NOTIFICATION_CHANNEL_ID,
            "CRM3 critical safety",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Active CRM3 plant safety coordination alarms"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 800, 350, 800)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setSound(sound, audioAttributes)
        }
        notificationManager().createNotificationChannel(channel)
    }

    private fun showCriticalAlarmNotification(
        alarmId: String,
        title: String,
        body: String,
    ) {
        ensureCriticalAlarmChannel()
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            data = Uri.parse(
                "crm3://critical-alarm/${Uri.encode(alarmId)}",
            )
            putExtra(CRITICAL_ALARM_ID_EXTRA, alarmId)
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            notificationId(alarmId),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CRITICAL_NOTIFICATION_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setPriority(Notification.PRIORITY_MAX)
                .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
                .setVibrate(longArrayOf(0, 800, 350, 800))
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
        notificationManager().notify(
            notificationTag(alarmId),
            CRITICAL_NOTIFICATION_ID,
            notification,
        )
    }

    private fun notificationId(alarmId: String): Int = alarmId.hashCode() and Int.MAX_VALUE

    private fun notificationTag(alarmId: String): String =
        "$CRITICAL_NOTIFICATION_TAG_PREFIX$alarmId"

    /// Reports whether Android is currently blocking this application's own
    /// network access.
    ///
    /// A connectivity check answers "is there a network"; it answered yes
    /// throughout the 2026-09-09 incident while every request from this UID was
    /// refused with BLOCKED_REASON_APP_BACKGROUND. Only the per-UID blocked
    /// status distinguishes "the network is down" from "this app may not use
    /// it", and the operator message depends on that difference.
    private fun configureNetworkAccessChannel(flutterEngine: FlutterEngine) {
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NETWORK_ACCESS_CHANNEL,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    networkAccessSink = events
                    startNetworkAccessWatch()
                }

                override fun onCancel(arguments: Any?) {
                    stopNetworkAccessWatch()
                    networkAccessSink = null
                }
            },
        )
    }

    private fun startNetworkAccessWatch() {
        // onBlockedStatusChanged arrived in API 29. Below that the platform
        // exposes no per-UID blocked signal, so the app must not claim to know
        // one: it reports unknown and the caller keeps its existing wording.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            networkAccessSink?.success(STATUS_UNKNOWN)
            return
        }
        val manager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        if (manager == null) {
            networkAccessSink?.success(STATUS_UNKNOWN)
            return
        }
        stopNetworkAccessWatch()
        val callback =
            object : ConnectivityManager.NetworkCallback() {
                override fun onBlockedStatusChanged(network: Network, blocked: Boolean) {
                    networkAccessSink?.success(
                        if (blocked) STATUS_BLOCKED else STATUS_ALLOWED,
                    )
                }

                override fun onLost(network: Network) {
                    // Losing the network is a different condition from being
                    // blocked on it, and must not be reported as the same thing.
                    networkAccessSink?.success(STATUS_NO_NETWORK)
                }
            }
        val request =
            NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()
        try {
            manager.registerNetworkCallback(request, callback)
            networkAccessCallback = callback
        } catch (error: SecurityException) {
            networkAccessCallback = null
            networkAccessSink?.success(STATUS_UNKNOWN)
        }
    }

    private fun stopNetworkAccessWatch() {
        val callback = networkAccessCallback ?: return
        networkAccessCallback = null
        val manager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        try {
            manager?.unregisterNetworkCallback(callback)
        } catch (error: IllegalArgumentException) {
            // Already unregistered; nothing further to release.
        }
    }

    override fun onDestroy() {
        stopNetworkAccessWatch()
        networkAccessSink = null
        super.onDestroy()
    }

    private companion object {
        const val NETWORK_ACCESS_CHANNEL =
            "in.co.sail.bsl.crm3.bafops/network_access"
        const val STATUS_ALLOWED = "allowed"
        const val STATUS_BLOCKED = "blocked"
        const val STATUS_NO_NETWORK = "noNetwork"
        const val STATUS_UNKNOWN = "unknown"
        const val RECOVERY_STORAGE_CHANNEL =
            "in.co.sail.bsl.crm3.bafops/recovery_storage"
        const val CRITICAL_ALARM_CHANNEL =
            "in.co.sail.bsl.crm3.bafops/critical_alarm"
        const val CRITICAL_NOTIFICATION_CHANNEL_ID = "crm3_critical_safety"
        const val CRITICAL_NOTIFICATION_ID = 0
        const val CRITICAL_ALARM_ID_EXTRA = "criticalAlarmId"
        const val CRITICAL_NOTIFICATION_TAG_PREFIX = "critical-alarm-"
        val DIAL_VALUE = Regex("^\\+?\\d{2,15}$")
    }
}
