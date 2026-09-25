import { Router, Request, Response } from 'express';
import { supabase } from '../db/supabase';

const router = Router();

// GET /api/calendar-overrides
router.get('/', async (req: Request, res: Response) => {
    try {
        const date = req.query.date as string;
        const mode = req.query.mode as string;

        let query = supabase
            .from('calendar_overrides')
            .select('id, title, message, override_date, start_time, end_time, target_mode')
            .eq('is_active', true);

        if (date) {
            query = query.eq('override_date', date);
        }

        if (mode) {
            query = query.in('target_mode', [mode, 'both']);
        }

        const { data, error } = await query.order('override_date', { ascending: false });

        if (error) throw error;

        // Add backward compatibility for old mobile app versions
        const mappedData = (data || []).map(item => ({
            ...item,
            date: item.override_date,
            isHoliday: true
        }));

        res.json(mappedData);
    } catch (err: any) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

export default router;
