import 'package:supabase_flutter/supabase_flutter.dart';

// ── Supabase credentials ──
const supabaseUrl = 'https://silfunnzqycdimckeryu.supabase.co';
const supabaseAnonKey =
    'sb_publishable_b5kGcDl-icAiFFFWztFWQQ_L32xVrKb';

/// Global shorthand — use `supabase.from(...)`, `supabase.auth`, etc.
SupabaseClient get supabase => Supabase.instance.client;
