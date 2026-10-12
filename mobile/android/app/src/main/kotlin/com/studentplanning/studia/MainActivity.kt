package com.studentplanning.studia

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

private const val CHANNEL = "studia/reminders"
private const val PERMISSION_REQUEST = 7841
private const val PREFS = "studia_local_alarms"
private const val KEY = "future_alerts"

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(allowed(this))
                "requestPermission" -> {
                    if (allowed(this)) result.success(true)
                    else if (Build.VERSION.SDK_INT >= 33) {
                        if (permissionResult != null) result.error("busy", "Permission en cours", null)
                        else {
                            permissionResult = result
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), PERMISSION_REQUEST)
                        }
                    } else result.success(true)
                }
                "replace" -> {
                    if (!allowed(this)) result.error("permission", "Activez les notifications du téléphone", null)
                    else try {
                        @Suppress("UNCHECKED_CAST")
                        val entries = call.arguments as? List<Map<String, Any>> ?: emptyList()
                        LocalAlarmStore.replace(this, entries)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("schedule", e.message ?: "Planification impossible", null)
                    }
                }
                "cancel" -> {
                    LocalAlarmStore.cancel(this, (call.arguments as Number).toInt())
                    result.success(null)
                }
                "scheduleTest" -> {
                    if (!allowed(this)) result.error("permission", "Activez les notifications", null)
                    else try {
                        result.success(LocalAlarmStore.scheduleTest(this))
                    } catch (e: Exception) {
                        result.error("schedule", e.message ?: "Test impossible", null)
                    }
                }
                "testNotification" -> {
                    if (!allowed(this)) result.error("permission", "Activez les notifications", null)
                    else {
                        val targetChannel = (call.arguments as? String)
                            ?: call.argument<String>("channel")
                            ?: "revisions"
                        val isCourse = targetChannel == "courses"
                        StudyAlarmReceiver().onReceive(this, Intent(this, StudyAlarmReceiver::class.java)
                            .putExtra("id", if (isCourse) 2147000001 else 2147000000)
                            .putExtra("title", if (isCourse) "Cours dans 1 heure (test)" else "Rappel de révision (test)")
                            .putExtra("body", if (isCourse) "Le son Studia des cours du matin fonctionne sur ce téléphone." else "Les alertes locales fonctionnent sur ce téléphone.")
                            .putExtra("channel", if (isCourse) "courses" else "revisions"))
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST) {
            permissionResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            permissionResult = null
        }
    }
}

private fun allowed(context: Context): Boolean =
    Build.VERSION.SDK_INT < 33 || context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

internal object LocalAlarmStore {
    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private fun saved(context: Context): JSONArray = JSONArray(prefs(context).getString(KEY, "[]"))

    private fun pending(context: Context, id: Int, entry: JSONObject): PendingIntent {
        val intent = Intent(context, StudyAlarmReceiver::class.java)
            .putExtra("id", id)
            .putExtra("title", entry.optString("title"))
            .putExtra("body", entry.optString("body"))
            .putExtra("channel", entry.optString("channel"))
        return PendingIntent.getBroadcast(context, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun schedule(context: Context, entry: JSONObject) {
        val at = entry.getLong("at")
        if (at <= System.currentTimeMillis()) return
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val reminder = pending(context, entry.getInt("id"), entry)
        // Exact when Android permits it; otherwise Android may defer by a few minutes.
        if (Build.VERSION.SDK_INT >= 31 && !alarms.canScheduleExactAlarms())
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, reminder)
        else try {
            if (Build.VERSION.SDK_INT >= 23)
                alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, reminder)
            else alarms.setExact(AlarmManager.RTC_WAKEUP, at, reminder)
        } catch (_: SecurityException) {
            if (Build.VERSION.SDK_INT >= 23)
                alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, reminder)
            else alarms.set(AlarmManager.RTC_WAKEUP, at, reminder)
        }
    }

    fun replace(context: Context, entries: List<Map<String, Any>>) {
        val existing = saved(context).asObjects()
        for (entry in existing) {
            if (entry.getInt("id") != -1) cancelAlarm(context, entry)
        }
        val array = JSONArray()
        // The pending test is separate from the real weekly plan.
        for (entry in existing) {
            if (entry.getInt("id") == -1 && entry.getLong("at") > System.currentTimeMillis()) array.put(entry)
        }
        for (entry in entries) {
            val json = JSONObject(entry)
            if (json.getLong("at") > System.currentTimeMillis()) {
                schedule(context, json)
                array.put(json)
            }
        }
        prefs(context).edit().putString(KEY, array.toString()).apply()
    }

    // Independent diagnostic: never replace the user's real course/revision alarms.
    fun scheduleTest(context: Context): Long {
        // Real reminder IDs are always positive; -1 is reserved for this test.
        val testId = -1
        val at = System.currentTimeMillis() + 60_000L
        val keep = JSONArray()
        for (entry in saved(context).asObjects()) {
            if (entry.getInt("id") == testId) cancelAlarm(context, entry)
            else keep.put(entry)
        }
        val test = JSONObject()
            .put("id", testId)
            .put("at", at)
            .put("title", "Révision : rappel d'essai")
            .put("body", "Le rappel local fonctionne. Aucun vrai cours n'a été ajouté.")
            .put("channel", "revisions")
        schedule(context, test)
        keep.put(test)
        prefs(context).edit().putString(KEY, keep.toString()).apply()
        return at
    }

    fun cancel(context: Context, id: Int) {
        val keep = JSONArray()
        for (entry in saved(context).asObjects()) {
            if (entry.getInt("id") == id) cancelAlarm(context, entry)
            else keep.put(entry)
        }
        prefs(context).edit().putString(KEY, keep.toString()).apply()
    }

    fun restore(context: Context) {
        for (entry in saved(context).asObjects()) schedule(context, entry)
    }

    private fun cancelAlarm(context: Context, entry: JSONObject) {
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarms.cancel(pending(context, entry.getInt("id"), entry))
    }

    private fun JSONArray.asObjects() = (0 until length()).map { getJSONObject(it) }
}

class StudyAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!allowed(context)) return
        val isCourse = intent.getStringExtra("channel") == "courses"
        // Channel sound is immutable after creation on Android 8+. New IDs are
        // required for existing installations that already created silent/default
        // "courses" and "revisions" channels. Users may still mute these channels.
        val channelId = if (isCourse) "courses_studia_v2" else "revisions_studia_v2"
        val soundRes = if (isCourse) R.raw.studia_course else R.raw.studia_revision
        val sound = Uri.parse("android.resource://${context.packageName}/$soundRes")
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(channelId,
                if (isCourse) "Cours · son Studia" else "Révisions · son Studia",
                NotificationManager.IMPORTANCE_DEFAULT)
            channel.setSound(sound, attributes)
            manager.createNotificationChannel(channel)
        }
        val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, channelId)
                      else Notification.Builder(context).setSound(sound, attributes)
        val notification = builder.setContentTitle(intent.getStringExtra("title"))
            .setContentText(intent.getStringExtra("body"))
            .setSmallIcon(R.drawable.ic_launcher_monochrome)
            .setAutoCancel(true).setContentIntent(open).build()
        manager.notify(intent.getIntExtra("id", 0), notification)
    }
}

class RestoreAlarmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) LocalAlarmStore.restore(context)
    }
}
