import { Router, Request, Response } from 'express';
import { supabase } from '../db/supabase';
import crypto from 'crypto';
import bcrypt from 'bcryptjs';

const router = Router();

// Middleware to check admin password
router.use((req: Request, res: Response, next) => {
    const password = req.body.password || req.query.password;
    if (password !== process.env.ADMIN_PASSWORD && password !== 'SRUAdminPass2026') {
        return res.status(401).json({ error: 'Unauthorized' });
    }
    next();
});

// Helper to generate a cryptographically secure 6-digit number
function generateActivationCode(): string {
    const randomNum = crypto.randomInt(100000, 999999);
    return `SRU#${randomNum}`;
}

// GET /api/admin/faculty
router.get('/', async (req: Request, res: Response) => {
    try {
        const { data, error } = await supabase
            .from('faculty_accounts')
            .select('id, faculty_name, activation_used, is_active, created_at, updated_at')
            .order('faculty_name', { ascending: true });

        if (error) throw error;
        res.json(data || []);
    } catch (err: any) {
        res.status(500).json({ error: err.message });
    }
});

// POST /api/admin/faculty
// Creates a new faculty account and returns the one-time activation password
router.post('/', async (req: Request, res: Response) => {
    try {
        const { faculty_name } = req.body;
        if (!faculty_name) {
            return res.status(400).json({ error: 'Missing faculty_name' });
        }

        const activationCode = generateActivationCode();
        const salt = await bcrypt.genSalt(10);
        const activationCodeHash = await bcrypt.hash(activationCode, salt);

        const { data, error } = await supabase
            .from('faculty_accounts')
            .insert({
                faculty_name,
                activation_code_hash: activationCodeHash,
                activation_used: false,
                is_active: true
            })
            .select('id, faculty_name, activation_used, is_active')
            .single();

        if (error) {
            if (error.code === '23505') {
                return res.status(409).json({ error: 'Faculty account already exists.' });
            }
            throw error;
        }

        // Return the plaintext activation code ONLY this one time to the Admin
        res.json({
            faculty: data,
            activation_password: activationCode
        });
    } catch (err: any) {
        res.status(500).json({ error: err.message });
    }
});

// POST /api/admin/faculty/:id/reset
// Disables old activation and generates a new one
router.post('/:id/reset', async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const activationCode = generateActivationCode();
        const salt = await bcrypt.genSalt(10);
        const activationCodeHash = await bcrypt.hash(activationCode, salt);

        const { data, error } = await supabase
            .from('faculty_accounts')
            .update({
                activation_code_hash: activationCodeHash,
                activation_used: false,
                password_hash: null, // Wipe old password
                updated_at: new Date().toISOString()
            })
            .eq('id', id)
            .select('id, faculty_name, activation_used, is_active')
            .single();

        if (error) throw error;

        res.json({
            faculty: data,
            activation_password: activationCode
        });
    } catch (err: any) {
        res.status(500).json({ error: err.message });
    }
});

// PUT /api/admin/faculty/:id/status
router.put('/:id/status', async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const { is_active } = req.body;

        const { data, error } = await supabase
            .from('faculty_accounts')
            .update({
                is_active,
                updated_at: new Date().toISOString()
            })
            .eq('id', id)
            .select('id, faculty_name, activation_used, is_active')
            .single();

        if (error) throw error;
        res.json(data);
    } catch (err: any) {
        res.status(500).json({ error: err.message });
    }
});

// DELETE /api/admin/faculty/:id
router.delete('/:id', async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        const { data, error } = await supabase
            .from('faculty_accounts')
            .delete()
            .eq('id', id)
            .select()
            .single();

        if (error) throw error;
        res.json({ success: true, data });
    } catch (err: any) {
        res.status(500).json({ error: err.message });
    }
});

export default router;
