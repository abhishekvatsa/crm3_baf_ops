package `in`.co.sail.bsl.crm3.bafops

import android.system.Os
import android.system.OsConstants
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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

    private companion object {
        const val RECOVERY_STORAGE_CHANNEL =
            "in.co.sail.bsl.crm3.bafops/recovery_storage"
    }
}
