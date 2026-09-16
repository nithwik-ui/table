import express, { Request, Response } from 'express';
import { SRUClient } from '../sru/sru-client';

const router = express.Router();
const client = new SRUClient();

interface CacheEntry {
  rooms: Array<{ name: string; type: string }>;
  timestamp: number;
}

// In-memory cache for free classrooms per (day, time) slot
const roomsCache = new Map<string, CacheEntry>();

// Deduplicate concurrent in-flight requests for the same slot
const inFlightRequests = new Map<string, Promise<Array<{ name: string; type: string }>>>();

// Cache TTL: 15 minutes
const CACHE_TTL_MS = 15 * 60 * 1000;

function getCacheKey(day: string, time: string): string {
  return `${day.trim().toLowerCase()}_${time.trim()}`;
}

// GET /api/rooms/free?day=<day>&time=<time>
router.get('/free', async (req: Request, res: Response) => {
  try {
    const { day, time } = req.query;
    if (!day || !time || typeof day !== 'string' || typeof time !== 'string') {
      return res.status(400).json({ error: 'Missing day or time parameters' });
    }

    const key = getCacheKey(day, time);
    const cached = roomsCache.get(key);
    const now = Date.now();

    // 1. If we have a fresh cached entry (within 15 minutes), return immediately
    if (cached && (now - cached.timestamp < CACHE_TTL_MS)) {
      return res.json({
        day,
        time,
        count: cached.rooms.length,
        rooms: cached.rooms,
      });
    }

    // 2. Fetch fresh rooms from upstream, deduplicating concurrent in-flight requests
    let promise = inFlightRequests.get(key);
    if (!promise) {
      promise = (async () => {
        try {
          const freshRooms = await client.getFreeRooms(day, time);
          if (freshRooms && freshRooms.length > 0) {
            roomsCache.set(key, { rooms: freshRooms, timestamp: Date.now() });
          }
          return freshRooms;
        } finally {
          inFlightRequests.delete(key);
        }
      })();
      inFlightRequests.set(key, promise);
    }

    try {
      const rooms = await promise;
      return res.json({
        day,
        time,
        count: rooms.length,
        rooms,
      });
    } catch (upstreamErr: any) {
      // 3. Resilient Fallback:
      // If upstream failed but we have ANY previous cache entry for this slot, serve it
      if (cached && cached.rooms && cached.rooms.length > 0) {
        console.warn(`[Rooms API] Upstream failed for ${day} ${time} (${upstreamErr.message}). Serving stale cache.`);
        return res.json({
          day,
          time,
          count: cached.rooms.length,
          rooms: cached.rooms,
        });
      }
      // If no cache at all, propagate the error
      throw upstreamErr;
    }
  } catch (err: any) {
    console.error(`[Rooms API] Error fetching free rooms:`, err.message);
    res.status(500).json({ error: err.message });
  }
});

export default router;
