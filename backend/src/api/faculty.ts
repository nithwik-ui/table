import express, { Request, Response } from 'express';
import { SRUClient } from '../sru/sru-client';
import { supabase } from '../db/supabase';

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
    let { faculty } = req.query;
    if (!faculty || typeof faculty !== 'string') {
      return res.status(400).json({ error: 'Missing faculty parameter' });
    }

    let targetFacultyId = faculty;

    // Check if faculty is a UUID (length 36, contains hyphens)
    if (faculty.length === 36 && faculty.includes('-')) {
      const { data, error } = await supabase
        .from('faculty_accounts')
        .select('faculty_name')
        .eq('id', faculty)
        .single();
      
      if (error || !data) {
        return res.status(404).json({ error: 'Faculty account not found' });
      }

      const facultyName = data.faculty_name;
      
      // Fetch faculty list and find the SRU ID
      const list = await client.getFacultyList();
      const sruFaculty = list.find((f: any) => f.name.trim() === facultyName.trim());
      
      if (!sruFaculty) {
        return res.status(404).json({ error: `Could not find SRU internal ID for ${facultyName}` });
      }
      
      targetFacultyId = sruFaculty.id;
    }

    const raw = await client.getFacultyTimetable(targetFacultyId);
    let normalized = client.normalize(raw);
    
    // Inject any test classes from the database
    const { data: testClasses } = await supabase
      .from('faculty_timetable_entries')
      .select('*')
      .eq('faculty_id', targetFacultyId);
      
    if (testClasses && testClasses.length > 0) {
      normalized = [...normalized, ...testClasses.map(tc => ({
        day: tc.day,
        start_time: tc.start_time,
        end_time: tc.end_time,
        subject: tc.subject,
        faculty: tc.faculty,
        room: tc.room,
        semester: tc.semester,
        ltp: tc.ltp
      }))];
    }
    
    res.json(normalized);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
