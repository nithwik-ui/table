export interface TimetableEntry {
  id: string;
  batch_id: string;
  day: string;
  start_time: string;
  end_time: string;
  subject: string;
  faculty: string;
  room?: string;
  last_synced: string;
}

export interface TimetableChange {
  id: string;
  batch_id: string;
  timetable_entry_id: string;
  change_type: string;
  field_name: string;
  old_value: string;
  new_value: string;
  detected_at: string;
}

export interface DeviceInfo {
  id: string;
  device_id: string;
  fcm_token: string;
  batch_id: string;
  app_version: string;
  last_active: string;
}

export interface AdminMetrics {
  counts: {
    batches: number;
    degrees: number;
    years: number;
    devices: number;
  };
  recentChanges: TimetableChange[];
}

export interface BatchData {
  id: string;
  degree: string;
  year: string;
  name: string;
}
