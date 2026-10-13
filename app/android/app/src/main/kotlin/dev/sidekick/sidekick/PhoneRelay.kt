package dev.sidekick.sidekick

import android.Manifest
import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.io.File

/**
 * What this phone passes on to paired computers by itself: its
 * notifications ([NotificationRelay]) and new screenshots
 * ([ScreenshotWatcher]). Both call Dart on `sidekick/phone`
 * (lib/platform/phone_relay.dart), which sends them on.
 */
object PhoneRelay {
    private val main = Handler(Looper.getMainLooper())

    fun send(context: Context, method: String, args: Map<String, Any>) = main.post {
        // Starts Sidekick's engine if nothing else has (after a reboot).
        SidekickEngine.get(context.applicationContext)
        SidekickEngine.phone?.invokeMethod(method, args)
    }

    /** Settings → Show notifications on computers (shared_preferences). */
    fun relayWanted(context: Context): Boolean =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getBoolean("flutter.relayNotifications", false)

    fun notificationAccess(context: Context): Boolean {
        val enabled = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners") ?: return false
        val me = ComponentName(context, NotificationRelay::class.java)
        return enabled.split(':').any { ComponentName.unflattenFromString(it) == me }
    }

    fun openNotificationAccess(context: Context) {
        val intent = if (Build.VERSION.SDK_INT >= 30) {
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).putExtra(
                Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                ComponentName(context, NotificationRelay::class.java).flattenToString(),
            )
        } else {
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        }
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}

/**
 * Android hands Sidekick every notification once it has notification access
 * (Settings → Show notifications on computers). Ongoing ones (music,
 * downloads, Sidekick's own), group summaries, private ones and system
 * chatter are left out.
 */
class NotificationRelay : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (!PhoneRelay.relayWanted(this) || sbn.packageName == packageName || sbn.isOngoing) return
        val n = sbn.notification
        if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        if (n.visibility == Notification.VISIBILITY_SECRET) return
        if (n.category in skipped) return
        val extras = n.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT) ?: extras.getCharSequence(Notification.EXTRA_TEXT))
            ?.toString().orEmpty()
        if (title.isBlank() && text.isBlank()) return
        PhoneRelay.send(this, "notification", mapOf("app" to appName(sbn), "title" to title.take(200), "text" to text.take(1000)))
    }

    /** The app's name, from the info Android puts in every notification
     *  (looking it up by package needs a permission Sidekick doesn't have). */
    private fun appName(sbn: StatusBarNotification): String = try {
        @Suppress("DEPRECATION")
        val info = sbn.notification.extras.getParcelable<ApplicationInfo>("android.appInfo")
        info?.let { packageManager.getApplicationLabel(it).toString() } ?: sbn.packageName
    } catch (_: Exception) {
        sbn.packageName
    }

    private companion object {
        val skipped = setOf(
            Notification.CATEGORY_SERVICE,
            Notification.CATEGORY_PROGRESS,
            Notification.CATEGORY_TRANSPORT,
            Notification.CATEGORY_SYSTEM,
            Notification.CATEGORY_STATUS,
        )
    }
}

/**
 * New screenshots (Settings → Send screenshots to computers): watches the
 * photo library and copies each new one from a Screenshots folder to the
 * app's cache for Dart to send. Needs permission to read photos.
 */
object ScreenshotWatcher {
    private var observer: ContentObserver? = null
    private var lastId = -1L

    val permission: String
        get() = if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_IMAGES else Manifest.permission.READ_EXTERNAL_STORAGE

    fun allowed(context: Context) = context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    fun start(context: Context) {
        if (observer != null) return
        val app = context.applicationContext
        val watcher = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                Thread { check(app) }.start()
            }
        }
        app.contentResolver.registerContentObserver(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, true, watcher)
        observer = watcher
    }

    fun stop(context: Context) {
        observer?.let { context.applicationContext.contentResolver.unregisterContentObserver(it) }
        observer = null
    }

    @Synchronized
    private fun check(context: Context) {
        val columns = mutableListOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.DATE_ADDED,
        )
        @Suppress("DEPRECATION")
        val where = if (Build.VERSION.SDK_INT >= 29) MediaStore.Images.Media.RELATIVE_PATH else MediaStore.Images.Media.DATA
        columns += where
        if (Build.VERSION.SDK_INT >= 29) columns += MediaStore.Images.Media.IS_PENDING
        val cursor = try {
            context.contentResolver.query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                columns.toTypedArray(),
                null,
                null,
                "${MediaStore.Images.Media.DATE_ADDED} DESC",
            )
        } catch (_: SecurityException) {
            null
        } ?: return
        cursor.use {
            if (!it.moveToFirst()) return
            val id = it.getLong(0)
            val name = it.getString(1) ?: "Screenshot.png"
            val added = it.getLong(2)
            val folder = it.getString(3).orEmpty()
            val pending = Build.VERSION.SDK_INT >= 29 && it.getInt(4) != 0
            // Only just taken, finished writing, and not sent already.
            if (pending || id == lastId) return
            if (System.currentTimeMillis() / 1000 - added > 20) return
            if (!folder.contains("screenshot", ignoreCase = true) && !name.contains("screenshot", ignoreCase = true)) return
            lastId = id
            val uri = Uri.withAppendedPath(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id.toString())
            val dir = File(context.cacheDir, "screenshots").apply { mkdirs() }
            val copy = File(dir, name)
            try {
                context.contentResolver.openInputStream(uri)?.use { input -> copy.outputStream().use { input.copyTo(it) } }
            } catch (_: Exception) {
                return
            }
            PhoneRelay.send(context, "screenshot", mapOf("path" to copy.path, "name" to name))
        }
    }
}
