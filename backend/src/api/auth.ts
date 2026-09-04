import { Router, Request, Response } from 'express';
import { supabase } from '../db/supabase';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

const router = Router();
const JWT_SECRET = process.env.JWT_SECRET || 'fallback_sru_jwt_secret_2026';

// In-memory sliding window rate limiter for auth routes
const rateLimitMap = new Map<string, number[]>();

function checkRateLimit(ip: string): boolean {
    const now = Date.now();
    const windowMs = 15 * 60 * 1000; // 15 minutes
    const maxAttempts = 5;

    let attempts = rateLimitMap.get(ip) || [];
    // Filter out attempts older than window
    attempts = attempts.filter(timestamp => now - timestamp < windowMs);
    
    if (attempts.length >= maxAttempts) {
        rateLimitMap.set(ip, attempts);
        return false; // Rate limit exceeded
    }

    attempts.push(now);
    rateLimitMap.set(ip, attempts);
    return true;
}

function clearRateLimit(ip: string) {
    rateLimitMap.delete(ip);
}

// GET /api/faculty/search
router.get('/search', async (req: Request, res: Response) => {
    try {
        const query = req.query.q as string;
        if (!query || query.length < 2) {
            return res.status(400).json({ error: 'Search query must be at least 2 characters.' });
        }

        const { data, error } = await supabase
            .from('faculty_accounts')
            .select('id, faculty_name')
            .eq('is_active', true)
            .ilike('faculty_name', `%${query}%`)
            .limit(10);

        if (error) throw error;
        res.json(data || []);
    } catch (err: any) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

// POST /api/faculty/activate
router.post('/activate', async (req: Request, res: Response) => {
    const ip = req.ip || req.socket.remoteAddress || 'unknown';
    if (!checkRateLimit(ip)) {
        return res.status(429).json({ error: 'Too many attempts. Please try again later.' });
    }

    try {
        const { faculty_id, activation_password, new_password } = req.body;
        if (!faculty_id || !activation_password || !new_password) {
            console.log(`[AUTH] Activation failed for ${faculty_id || 'unknown'}: Missing parameters`);
            return res.status(400).json({ error: 'Missing parameters.' });
        }
        
        const cleanActivation = activation_password.trim();
        if (!/^SRU#\d{6}$/.test(cleanActivation)) {
            console.log(`[AUTH] Activation failed for ${faculty_id}: Invalid activation format`);
            return res.status(400).json({ error: 'Activation code must be exactly SRU# followed by 6 digits.' });
        }

        if (new_password.length < 6) {
            console.log(`[AUTH] Activation failed for ${faculty_id}: Password too short`);
            return res.status(400).json({ error: 'Password must be at least 6 characters.' });
        }

        // Fetch account
        const { data: account, error: accErr } = await supabase
            .from('faculty_accounts')
            .select('*')
            .eq('id', faculty_id)
            .eq('is_active', true)
            .single();

        if (accErr || !account) {
            console.log(`[AUTH] Activation failed for ${faculty_id}: Account not found or inactive`);
            return res.status(401).json({ error: 'Invalid faculty credentials.' });
        }

        if (account.activation_used) {
            console.log(`[AUTH] Activation failed for ${faculty_id}: Activation code already used`);
            return res.status(401).json({ error: 'Invalid faculty credentials.' });
        }

        // Verify one-time hash
        const isMatch = await bcrypt.compare(cleanActivation, account.activation_code_hash || '');
        if (!isMatch) {
            console.log(`[AUTH] Activation failed for ${faculty_id}: Incorrect activation code`);
            return res.status(401).json({ error: 'Invalid faculty credentials.' });
        }

        // Success! Set new password
        const salt = await bcrypt.genSalt(10);
        const newPasswordHash = await bcrypt.hash(new_password, salt);

        const { error: updErr } = await supabase
            .from('faculty_accounts')
            .update({
                password_hash: newPasswordHash,
                activation_used: true,
                activation_code_hash: null,
                updated_at: new Date().toISOString()
            })
            .eq('id', faculty_id);

        if (updErr) throw updErr;

        clearRateLimit(ip);
        console.log(`[AUTH] Activation SUCCESS for ${faculty_id}`);

        // Issue JWT token
        const token = jwt.sign(
            { id: account.id, faculty_name: account.faculty_name, mode: 'faculty' },
            JWT_SECRET,
            { expiresIn: '30d' }
        );

        res.json({ success: true, token, faculty_name: account.faculty_name });
    } catch (err: any) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

// POST /api/faculty/login
router.post('/login', async (req: Request, res: Response) => {
    const ip = req.ip || req.socket.remoteAddress || 'unknown';
    if (!checkRateLimit(ip)) {
        return res.status(429).json({ error: 'Too many attempts. Please try again later.' });
    }

    try {
        const { faculty_id, password } = req.body;
        if (!faculty_id || !password) {
            console.log(`[AUTH] Login failed for ${faculty_id || 'unknown'}: Missing parameters`);
            return res.status(400).json({ error: 'Missing parameters.' });
        }

        const { data: account, error: accErr } = await supabase
            .from('faculty_accounts')
            .select('*')
            .eq('id', faculty_id)
            .eq('is_active', true)
            .single();

        if (accErr || !account || !account.activation_used || !account.password_hash) {
            console.log(`[AUTH] Login failed for ${faculty_id}: Account not found, inactive, or not activated`);
            return res.status(401).json({ error: 'Invalid faculty credentials.' });
        }

        const isMatch = await bcrypt.compare(password, account.password_hash);
        if (!isMatch) {
            console.log(`[AUTH] Login failed for ${faculty_id}: Incorrect password`);
            return res.status(401).json({ error: 'Invalid faculty credentials.' });
        }

        clearRateLimit(ip);
        console.log(`[AUTH] Login SUCCESS for ${faculty_id}`);

        // Issue JWT token
        const token = jwt.sign(
            { id: account.id, faculty_name: account.faculty_name, mode: 'faculty' },
            JWT_SECRET,
            { expiresIn: '30d' }
        );

        res.json({ success: true, token, faculty_name: account.faculty_name });
    } catch (err: any) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

export default router;
