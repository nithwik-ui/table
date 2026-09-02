import express, { Request, Response } from 'express';
import { SRUClient } from '../sru/sru-client';

const router = express.Router();
const client = new SRUClient();

// GET /api/faculty/list
router.get('/list', async (req: Request, res: Response) => {
  try {
    const list = await client.getFacultyList();
    res.json(list);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/faculty/timetable?faculty=<faculty_id>
router.get('/timetable', async (req: Request, res: Response) => {
  try {
    const { faculty } = req.query;
    if (!faculty || typeof faculty !== 'string') {
      return res.status(400).json({ error: 'Missing faculty parameter' });
    }

    const raw = await client.getFacultyTimetable(faculty);
    const normalized = client.normalize(raw);
    
    // Optional: map to match what the frontend expects for batch schedules
    res.json(normalized);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
