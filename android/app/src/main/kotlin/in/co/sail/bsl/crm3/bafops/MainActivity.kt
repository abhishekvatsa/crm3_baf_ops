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
            if (call.method != "syncDirectory") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val rawPath = call.argument<String>("directoryPath")
            if (rawPath.isNullOrBlank()) {
                result.error(
                    "directory-path-invalid",
                    "A recovery-journal directory path is required.",
                    null,
                )
                return@setMethodCallHandler
            }

            try {
                val directory = File(rawPath).canonicalFile
                val appDataDirectory = File(applicationInfo.dataDir).canonicalFile
                val insideAppData = directory.path == appDataDirectory.path ||
                    directory.path.startsWith(appDataDirectory.path + File.separator)
                if (!insideAppData || !directory.isDirectory) {
                    result.error(
                        "directory-path-rejected",
                        "Only an existing application-private directory can be synchronized.",
                        null,
                    )
                    return@setMethodCallHandler
                }

                val descriptor = Os.open(
                    directory.path,
                    OsConstants.O_RDONLY,
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
                    "directory-sync-failed",
                    error.message ?: "The recovery-journal directory could not be synchronized.",
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
