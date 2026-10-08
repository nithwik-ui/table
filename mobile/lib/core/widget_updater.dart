import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'storage.dart';

class WidgetUpdater {
  static const String appGroupId = 'sru_timetable_widget'; // Android AppWidgetProvider name or string id if needed
  static const String androidWidgetName = 'TimetableWidgetProvider';

  static Future<void> updateWidgetInfo() async {
    final mode = StorageService.getUserMode();
    if (mode == null) {
      await HomeWidget.saveWidgetData<String>('timetable_data', '[]');
      await HomeWidget.saveWidgetData<String>('overrides_data', '[]');
      await HomeWidget.saveWidgetData<String>('user_mode', 'none');
      await HomeWidget.updateWidget(androidName: androidWidgetName);
      return;
    }

    List<dynamic> timetable = [];
    List<dynamic> overrides = [];

    if (mode == 'student') {
      timetable = StorageService.getTimetableCache();
      overrides = StorageService.getStudentCalendarOverridesCache();
    } else {
      timetable = StorageService.getFacultyTimetableCache();
      overrides = StorageService.getFacultyCalendarOverridesCache();
    }

    await HomeWidget.saveWidgetData<String>('timetable_data', jsonEncode(timetable));
    await HomeWidget.saveWidgetData<String>('overrides_data', jsonEncode(overrides));
    await HomeWidget.saveWidgetData<String>('user_mode', mode);
    
    await HomeWidget.updateWidget(androidName: androidWidgetName);
  }
}
