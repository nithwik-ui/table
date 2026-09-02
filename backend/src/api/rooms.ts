import express, { Request, Response } from 'express';
import { SRUClient } from '../sru/sru-client';

const router = express.Router();
const client = new SRUClient();

// GET /api/rooms/free?day=<day>&time=<time>
router.get('/free', async (req: Request, res: Response) => {
  try {
    const { day, time } = req.query;
    if (!day || !time || typeof day !== 'string' || typeof time !== 'string') {
      return res.status(400).json({ error: 'Missing day or time parameters' });
    }

    const rooms = await client.getFreeRooms(day, time);
    
    res.json({
      day,
      time,
      count: rooms.length,
      rooms
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
