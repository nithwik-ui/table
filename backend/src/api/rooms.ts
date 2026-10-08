import express, { Request, Response } from 'express';
import { supabase } from '../db/supabase';

const router = express.Router();

// Cache all known rooms (could also be stored in a dedicated table)
let allRoomsCache: Array<{ name: string; type: string }> | null = null;
let allRoomsCacheTime = 0;
const ROOMS_CACHE_TTL = 24 * 60 * 60 * 1000; // 24 hours

async function getAllRooms(): Promise<Array<{ name: string; type: string }>> {
  if (allRoomsCache && Date.now() - allRoomsCacheTime < ROOMS_CACHE_TTL) {
    return allRoomsCache;
  }
  
  // 1. Fetch distinct rooms from student timetable_entries
  const { data: studentRooms, error: studentErr } = await supabase
    .from('timetable_entries')
    .select('room, ltp')
    .not('room', 'is', null)
    .neq('room', '')
    .neq('room', 'TBA');
    
  if (studentErr) {
    console.error('[Rooms API] Student rooms error:', studentErr.message);
  }

  // 2. Fetch distinct rooms from faculty_timetable_entries
  const { data: facultyRooms } = await supabase
    .from('faculty_timetable_entries')
    .select('room, ltp')
    .not('room', 'is', null)
    .neq('room', '')
    .neq('room', 'TBA');

  const roomMap = new Map<string, string>();
  
  if (studentRooms) {
    for (const entry of studentRooms) {
      if (entry.room && typeof entry.room === 'string') {
        const roomStr = entry.room.trim();
        if (roomStr.length > 0) {
          roomMap.set(roomStr, entry.ltp || 'Lecture');
        }
      }
    }
  }

  if (facultyRooms) {
    for (const entry of facultyRooms) {
      if (entry.room && typeof entry.room === 'string') {
        const roomStr = entry.room.trim();
        if (roomStr.length > 0 && !roomMap.has(roomStr)) {
          roomMap.set(roomStr, entry.ltp || 'Lecture');
        }
      }
    }
  }

  const rooms = Array.from(roomMap.entries()).map(([name, type]) => ({ name, type })).sort((a, b) => a.name.localeCompare(b.name));
  
  allRoomsCache = rooms;
  allRoomsCacheTime = Date.now();
  return rooms;
}

// GET /api/rooms/free?day=<day>&time=<time>
router.get('/free', async (req: Request, res: Response) => {
  try {
    const { day, time } = req.query;
    if (!day || !time || typeof day !== 'string' || typeof time !== 'string') {
      return res.status(400).json({ error: 'Missing day or time parameters' });
    }

    const allRooms = await getAllRooms();

    // Query for classes happening at this day and time
    // For string time "HH:MM", ensure zero-padded string comparison works
    const rawTime = time.trim();
    const searchTime = rawTime.length === 4 ? `0${rawTime}` : rawTime;
    
    // Normalize Day (Title Case e.g. "Monday", and fallback lowercase "monday")
    const dayTrimmed = day.trim();
    const titleDay = dayTrimmed.charAt(0).toUpperCase() + dayTrimmed.slice(1).toLowerCase();
    const lowerDay = dayTrimmed.toLowerCase();

    // Query occupied rooms from student timetable
    const { data: studentOccupied, error: studentErr } = await supabase
      .from('timetable_entries')
      .select('room, start_time, end_time')
      .or(`day.eq.${titleDay},day.eq.${lowerDay}`)
      .lte('start_time', searchTime)
      .gt('end_time', searchTime)
      .not('room', 'is', null)
      .neq('room', '');

    if (studentErr) {
      console.error('[Rooms API] Query error student timetable:', studentErr.message);
    }

    // Query occupied rooms from faculty timetable
    const { data: facultyOccupied } = await supabase
      .from('faculty_timetable_entries')
      .select('room, start_time, end_time')
      .or(`day.eq.${titleDay},day.eq.${lowerDay}`)
      .lte('start_time', searchTime)
      .gt('end_time', searchTime)
      .not('room', 'is', null)
      .neq('room', '');

    const occupiedRooms = new Set<string>();
    
    if (studentOccupied) {
      for (const entry of studentOccupied) {
        if (entry.room) {
          occupiedRooms.add(entry.room.trim());
        }
      }
    }

    if (facultyOccupied) {
      for (const entry of facultyOccupied) {
        if (entry.room) {
          occupiedRooms.add(entry.room.trim());
        }
      }
    }

    // Filter free rooms
    const freeRooms = allRooms.filter(r => !occupiedRooms.has(r.name));

    return res.json({
      day: titleDay,
      time: searchTime,
      count: freeRooms.length,
      rooms: freeRooms,
    });
  } catch (err: any) {
    console.error(`[Rooms API] Error fetching free rooms:`, err.message);
    res.status(500).json({ error: err.message });
  }
});

export default router;
