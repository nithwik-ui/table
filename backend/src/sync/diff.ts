import { TimetableEntry } from '../sru/sru-client';

export interface DBTimetableEntry extends TimetableEntry {
  id: string;
}

export interface TimetableChangeInsert {
  batch_id: string;
  timetable_entry_id: string | null;
  change_type:
    | 'CLASS_ADDED'
    | 'CLASS_REMOVED'
    | 'SUBJECT_CHANGED'
    | 'FACULTY_CHANGED'
    | 'ROOM_CHANGED'
    | 'TIME_CHANGED'
    | 'LTP_CHANGED';
  field_name: string | null;
  old_value: string | null;
  new_value: string | null;
}

/**
 * Compares old timetable entries with new ones, returning detected differences.
 */
export function diffTimetables(
  batchId: string,
  oldEntries: DBTimetableEntry[],
  newEntries: TimetableEntry[]
): {
  changes: TimetableChangeInsert[];
  matchedOldEntryIds: string[];
} {
  const changes: TimetableChangeInsert[] = [];
  const matchedOld = new Set<string>();
  const matchedNew = new Set<number>();

  const recordChange = (
    entryId: string | null,
    type: TimetableChangeInsert['change_type'],
    fieldName: string | null,
    oldVal: string | null,
    newVal: string | null
  ) => {
    changes.push({
      batch_id: batchId,
      timetable_entry_id: entryId,
      change_type: type,
      field_name: fieldName,
      old_value: oldVal,
      new_value: newVal,
    });
  };

  // Step 1: Match by exact slot and subject (same day, same start time, same subject)
  for (let i = 0; i < newEntries.length; i++) {
    const newEntry = newEntries[i];
    const match = oldEntries.find(
      old =>
        !matchedOld.has(old.id) &&
        old.day === newEntry.day &&
        old.start_time === newEntry.start_time &&
        old.subject === newEntry.subject
    );

    if (match) {
      matchedOld.add(match.id);
      matchedNew.add(i);

      // Check for attribute updates
      if (match.room !== newEntry.room) {
        recordChange(match.id, 'ROOM_CHANGED', `room:${match.subject}`, match.room, newEntry.room);
      }
      if (match.faculty !== newEntry.faculty) {
        recordChange(match.id, 'FACULTY_CHANGED', `faculty:${match.subject}`, match.faculty, newEntry.faculty);
      }
      if (match.ltp !== newEntry.ltp) {
        recordChange(match.id, 'LTP_CHANGED', `ltp:${match.subject}`, match.ltp, newEntry.ltp);
      }
    }
  }

  // Step 2: Match by slot only (Subject Changed)
  for (let i = 0; i < newEntries.length; i++) {
    if (matchedNew.has(i)) continue;
    const newEntry = newEntries[i];
    const match = oldEntries.find(
      old =>
        !matchedOld.has(old.id) &&
        old.day === newEntry.day &&
        old.start_time === newEntry.start_time
    );

    if (match) {
      matchedOld.add(match.id);
      matchedNew.add(i);

      recordChange(match.id, 'SUBJECT_CHANGED', `subject:${match.subject}`, match.subject, newEntry.subject);

      // Check other properties as well
      if (match.room !== newEntry.room) {
        recordChange(match.id, 'ROOM_CHANGED', `room:${match.subject}`, match.room, newEntry.room);
      }
      if (match.faculty !== newEntry.faculty) {
        recordChange(match.id, 'FACULTY_CHANGED', `faculty:${match.subject}`, match.faculty, newEntry.faculty);
      }
      if (match.ltp !== newEntry.ltp) {
        recordChange(match.id, 'LTP_CHANGED', `ltp:${match.subject}`, match.ltp, newEntry.ltp);
      }
    }
  }

  // Step 3: Match by subject & faculty (Time Rescheduled)
  for (let i = 0; i < newEntries.length; i++) {
    if (matchedNew.has(i)) continue;
    const newEntry = newEntries[i];
    const match = oldEntries.find(
      old =>
        !matchedOld.has(old.id) &&
        old.subject === newEntry.subject &&
        old.faculty === newEntry.faculty
    );

    if (match) {
      matchedOld.add(match.id);
      matchedNew.add(i);

      recordChange(
        match.id,
        'TIME_CHANGED',
        `time:${match.subject}`,
        `${match.day} ${match.start_time}-${match.end_time}`,
        `${newEntry.day} ${newEntry.start_time}-${newEntry.end_time}`
      );

      if (match.room !== newEntry.room) {
        recordChange(match.id, 'ROOM_CHANGED', `room:${match.subject}`, match.room, newEntry.room);
      }
    }
  }

  // Step 4: Unmatched new items (Class Added)
  for (let i = 0; i < newEntries.length; i++) {
    if (matchedNew.has(i)) continue;
    const newEntry = newEntries[i];
    recordChange(
      null,
      'CLASS_ADDED',
      null,
      null,
      `${newEntry.subject} (${newEntry.ltp}) in ${newEntry.room} by ${newEntry.faculty}`
    );
  }

  // Step 5: Unmatched old items (Class Removed)
  for (const old of oldEntries) {
    if (matchedOld.has(old.id)) continue;
    recordChange(
      old.id,
      'CLASS_REMOVED',
      null,
      `${old.subject} (${old.ltp}) in ${old.room} by ${old.faculty}`,
      null
    );
  }

  return {
    changes,
    matchedOldEntryIds: Array.from(matchedOld),
  };
}
