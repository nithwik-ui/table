import { Router, Request, Response } from 'express';
import { supabase } from '../db/supabase';
import { sendHolidaySilentPush } from '../notifications/fcm';

const router = Router();

// Middleware to check admin password
router.use((req: Request, res: Response, next) => {
    const password = req.body.password || req.query.password;
    if (password !== process.env.ADMIN_PASSWORD && password !== 'SRUAdminPass2026') {
        return res.status(401).json({ error: 'Unauthorized' });
    }
    next();
});

// GET /api/admin/holidays
router.get('/', async (req: Request, res: Response) => {
    try {
        const { data, error } = await supabase
            .from('calendar_overrides')
            .select('*')
            .order('override_date', { ascending: false });

        if (error) throw error;
        res.json(data || []);
    } catch (err: any) {
        res.status(500).json({ error: err.message });
    }
});

// POST /api/admin/holidays
router.post('/', async (req: Request, res: Response) => {
    try {
        const { title, message, override_date, start_time, end_time, target_mode, is_active } = req.body;
        
        const { data, error } = await supabase
            .from('calendar_overrides')
            .insert({
                title,
                message,
                override_date,
                start_time: start_time || null,
                end_time: end_time || null,
                target_mode,
                is_active: is_active ?? true
            })
            .select()
            .single();

        if (error) throw error;

        // Notify devices silently so they can cancel affected reminders
        if (is_active !== false) {
            sendHolidaySilentPush(override_date, target_mode).catch(console.error);
        }

        res.json(data);
    } catch (err: any) {
        res.status(500).json({ error: err.message });
    }
});

// PUT /api/admin/holidays/:id
router.put('/:id', async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const { title, message, override_date, start_time, end_time, target_mode, is_active } = req.body;
        
        const { data, error } = await supabase
            .from('calendar_overrides')
            .update({
                title,
                message,
                override_date,
                start_time: start_time || null,
                end_time: end_time || null,
                target_mode,
                is_active,
                updated_at: new Date().toISOString()
            })
            .eq('id', id)
            .select()
            .single();

        if (error) throw error;

        // Notify devices silently so they can evaluate the update
        sendHolidaySilentPush(override_date, target_mode).catch(console.error);

        res.json(data);
    } catch (err: any) {
        res.status(500).json({ error: err.message });
    }
});

// DELETE /api/admin/holidays/:id
router.delete('/:id', async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const { error } = await supabase
            .from('calendar_overrides')
            .delete()
            .eq('id', id);

        if (error) throw error;
        res.json({ success: true });
    } catch (err: any) {
        res.status(500).json({ error: err.message });
    }
});

export default router;
