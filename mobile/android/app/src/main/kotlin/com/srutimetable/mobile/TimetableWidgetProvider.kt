package com.srutimetable.mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class TimetableWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, id = appWidgetId)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle?
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateAppWidget(context, appWidgetManager, id = appWidgetId)
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: IntArray? = null, id: Int? = null) {
        val views = RemoteViews(context.packageName, R.layout.widget_timetable)
        
        // Setup Intent to launch the app when widget is clicked
        val intent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context, 
            0, 
            intent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

        val prefs = context.getSharedPreferences("es.antonborri.home_widget.preferences", Context.MODE_PRIVATE)
        val timetableJson = prefs.getString("timetable_data", "[]") ?: "[]"
        val overridesJson = prefs.getString("overrides_data", "[]") ?: "[]"
        val userMode = prefs.getString("user_mode", "none") ?: "none"

        if (userMode == "none") {
            views.setTextViewText(R.id.widget_subject, "Set up your timetable")
            views.setTextViewText(R.id.widget_time, "Tap to open app")
            views.setViewVisibility(R.id.widget_status_container, View.GONE)
            if (id != null) {
                appWidgetManager.updateAppWidget(id, views)
            } else if (appWidgetId != null) {
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
            return
        }

        val cal = Calendar.getInstance()
        val currentDayIndex = cal.get(Calendar.DAY_OF_WEEK) // 1=Sun, 2=Mon...
        val dayNames = arrayOf("sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday")
        val currentDayName = dayNames[currentDayIndex - 1]
        
        val currentHour = cal.get(Calendar.HOUR_OF_DAY)
        val currentMinute = cal.get(Calendar.MINUTE)
        val currentTotalMinutes = currentHour * 60 + currentMinute
        
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val todayDateStr = dateFormat.format(cal.time)

        try {
            val timetableArray = JSONArray(timetableJson)
            val overridesArray = JSONArray(overridesJson)
            
            // Check for full day holiday override
            var isHoliday = false
            var holidayTitle = ""
            for (i in 0 until overridesArray.length()) {
                val override = overridesArray.getJSONObject(i)
                if (override.optString("override_date") == todayDateStr) {
                    val targetMode = override.optString("target_mode")
                    if (targetMode == "both" || targetMode == userMode) {
                        val startTime = override.optString("start_time")
                        if (startTime.isNullOrEmpty()) {
                            isHoliday = true
                            holidayTitle = override.optString("title", "Holiday")
                            break
                        }
                    }
                }
            }

            if (isHoliday) {
                views.setTextViewText(R.id.widget_subject, holidayTitle)
                views.setTextViewText(R.id.widget_time, "No classes today")
                views.setViewVisibility(R.id.widget_status_container, View.GONE)
                if (id != null) {
                    appWidgetManager.updateAppWidget(id, views)
                } else if (appWidgetId != null) {
                    appWidgetManager.updateAppWidget(appWidgetId, views)
                }
                return
            }

            // Filter today's classes
            val todayClasses = mutableListOf<JSONObject>()
            for (i in 0 until timetableArray.length()) {
                val c = timetableArray.getJSONObject(i)
                if (c.optString("day", "").lowercase() == currentDayName) {
                    todayClasses.add(c)
                }
            }
            
            // Sort by start time
            todayClasses.sortWith(Comparator { a, b ->
                val startA = parseMinutes(a.optString("start_time", ""))
                val startB = parseMinutes(b.optString("start_time", ""))
                startA.compareTo(startB)
            })

            // Determine status
            var nextClass: JSONObject? = null
            var ongoingClass: JSONObject? = null
            var lastClassEndTime = 0
            
            for (c in todayClasses) {
                // Check if this specific class is cancelled by override
                var isCancelled = false
                val cStartMin = parseMinutes(c.optString("start_time", ""))
                val cEndMin = parseMinutes(c.optString("end_time", ""))
                
                for (j in 0 until overridesArray.length()) {
                    val override = overridesArray.getJSONObject(j)
                    if (override.optString("override_date") == todayDateStr) {
                         val oStartMin = parseMinutes(override.optString("start_time", ""))
                         val oEndMin = parseMinutes(override.optString("end_time", ""))
                         if (oStartMin > 0 && oEndMin > 0 && cStartMin >= oStartMin && cStartMin <= oEndMin) {
                             isCancelled = true
                             break
                         }
                    }
                }

                if (!isCancelled) {
                    if (currentTotalMinutes in cStartMin until cEndMin) {
                        ongoingClass = c
                        break
                    } else if (currentTotalMinutes < cStartMin) {
                        nextClass = c
                        break
                    }
                    lastClassEndTime = maxOf(lastClassEndTime, cEndMin)
                }
            }

            if (ongoingClass != null) {
                // Ongoing class
                val subject = ongoingClass.optString("subject", "Unknown")
                val startMin = parseMinutes(ongoingClass.optString("start_time", ""))
                val endMin = parseMinutes(ongoingClass.optString("end_time", ""))
                val room = ongoingClass.optString("room", "").split("_")[0]
                
                views.setTextViewText(R.id.widget_subject, subject)
                views.setTextViewText(R.id.widget_time, "${formatTime(startMin)} - ${formatTime(endMin)}  •  $room")
                
                views.setViewVisibility(R.id.widget_status_container, View.VISIBLE)
                val remaining = endMin - currentTotalMinutes
                views.setTextViewText(R.id.widget_status, "$remaining min left")
                
                views.setViewVisibility(R.id.widget_progress, View.VISIBLE)
                val progress = ((currentTotalMinutes - startMin).toFloat() / (endMin - startMin) * 1000).toInt()
                views.setProgressBar(R.id.widget_progress, 1000, progress, false)
                
            } else if (nextClass != null) {
                // Check if there is a gap (free period / lunch)
                val startMin = parseMinutes(nextClass.optString("start_time", ""))
                if (lastClassEndTime > 0 && currentTotalMinutes >= lastClassEndTime && currentTotalMinutes < startMin) {
                    // Free period
                    val isLunch = (lastClassEndTime in 720..810) // e.g. 12:00 to 13:30 loosely
                    val title = if (isLunch) "Lunch Break" else "Free Period"
                    
                    views.setTextViewText(R.id.widget_subject, title)
                    views.setTextViewText(R.id.widget_time, "Next: ${nextClass.optString("subject")} at ${formatTime(startMin)}")
                    
                    views.setViewVisibility(R.id.widget_status_container, View.VISIBLE)
                    val remaining = startMin - currentTotalMinutes
                    views.setTextViewText(R.id.widget_status, "$remaining min left")
                    
                    views.setViewVisibility(R.id.widget_progress, View.VISIBLE)
                    val progress = ((currentTotalMinutes - lastClassEndTime).toFloat() / (startMin - lastClassEndTime) * 1000).toInt()
                    views.setProgressBar(R.id.widget_progress, 1000, progress, false)
                } else {
                    // Upcoming class (no prior class or long gap ignored)
                    val subject = nextClass.optString("subject", "Unknown")
                    val endMin = parseMinutes(nextClass.optString("end_time", ""))
                    val room = nextClass.optString("room", "").split("_")[0]
                    
                    views.setTextViewText(R.id.widget_subject, subject)
                    views.setTextViewText(R.id.widget_time, "${formatTime(startMin)} - ${formatTime(endMin)}  •  $room")
                    
                    views.setViewVisibility(R.id.widget_status_container, View.VISIBLE)
                    val remaining = startMin - currentTotalMinutes
                    views.setTextViewText(R.id.widget_status, "Starts in $remaining min")
                    views.setViewVisibility(R.id.widget_progress, View.GONE)
                }
            } else {
                if (todayClasses.isEmpty()) {
                    views.setTextViewText(R.id.widget_subject, "No classes today")
                    views.setTextViewText(R.id.widget_time, "Enjoy your free day!")
                } else {
                    views.setTextViewText(R.id.widget_subject, "No more classes today")
                    views.setTextViewText(R.id.widget_time, "Day complete ✓")
                }
                views.setViewVisibility(R.id.widget_status_container, View.GONE)
            }

        } catch (e: Exception) {
            e.printStackTrace()
            views.setTextViewText(R.id.widget_subject, "Timetable Error")
            views.setTextViewText(R.id.widget_time, "Please open the app")
            views.setViewVisibility(R.id.widget_status_container, View.GONE)
        }
        
        // Responsive Layout handling based on size
        if (id != null) {
            val options = appWidgetManager.getAppWidgetOptions(id)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
            // If the widget is extremely small vertically (e.g. 1x1 or 2x1), hide the status row
            if (minHeight in 1..60) {
                views.setViewVisibility(R.id.widget_status_container, View.GONE)
            }
        }

        if (id != null) {
            appWidgetManager.updateAppWidget(id, views)
        } else if (appWidgetId != null) {
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
    
    private fun parseMinutes(timeStr: String): Int {
        if (timeStr.isEmpty()) return 0
        val parts = timeStr.split(":")
        if (parts.size < 2) return 0
        return (parts[0].toIntOrNull() ?: 0) * 60 + (parts[1].toIntOrNull() ?: 0)
    }

    private fun formatTime(minutes: Int): String {
        val h = minutes / 60
        val m = minutes % 60
        val isPm = h >= 12
        val h12 = if (h == 0) 12 else if (h > 12) h - 12 else h
        val amPm = if (isPm) "PM" else "AM"
        val mStr = if (m < 10) "0$m" else "$m"
        return "$h12:$mStr $amPm"
    }
}
