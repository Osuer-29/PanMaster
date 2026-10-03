import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const response = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...corsHeaders, 'Content-Type': 'application/json' },
});

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return response({ error: 'Método no permitido.' }, 405);

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) return response({ error: 'Debes iniciar sesión como superadministrador.' }, 401);
    const token = authHeader.slice('Bearer '.length);
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !anonKey || !serviceKey) return response({ error: 'Faltan variables de entorno de Supabase en la función.' }, 500);

    const userClient = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: `Bearer ${token}` } }, auth: { persistSession: false } });
    const { data: userData, error: userError } = await userClient.auth.getUser(token);
    if (userError || !userData.user) return response({ error: 'La sesión no es válida. Inicia sesión de nuevo.' }, 401);

    const adminClient = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: profile, error: profileError } = await adminClient.from('profiles')
      .select('role,active').eq('id', userData.user.id).maybeSingle();
    if (profileError) return response({ error: `No se pudo validar el perfil: ${profileError.message}` }, 500);
    if (profile?.role !== 'superadmin' || profile.active !== true) return response({ error: 'Solo un superadministrador activo puede crear cuentas.' }, 403);

    const body = await req.json();
    const email = String(body.email ?? '').trim().toLowerCase();
    const password = String(body.password ?? '');
    const fullName = String(body.full_name ?? '').trim();
    const role = body.role === 'superadmin' ? 'superadmin' : 'employee';
    const active = body.active !== false;
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return response({ error: 'Escribe un correo electrónico válido.' }, 400);
    if (password.length < 8) return response({ error: 'La contraseña inicial debe tener al menos 8 caracteres.' }, 400);
    if (!fullName) return response({ error: 'Escribe el nombre completo del usuario.' }, 400);

    const { data: created, error: createError } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: fullName },
    });
    if (createError) {
      const msg = createError.message.toLowerCase().includes('already')
        ? 'Ese correo ya existe en Authentication. No lo vuelvas a crear; revisa la cuenta existente o restablece su contraseña.'
        : createError.message;
      return response({ error: msg }, 400);
    }
    if (!created.user) return response({ error: 'Supabase no devolvió el usuario creado.' }, 500);

    const { error: upsertError } = await adminClient.from('profiles').upsert({
      id: created.user.id,
      full_name: fullName,
      email,
      role,
      active,
    }, { onConflict: 'id' });
    if (upsertError) {
      // Keep the auth user visible and report the profile sync problem instead of hiding it.
      return response({ error: `La cuenta de acceso se creó, pero falló el perfil: ${upsertError.message}. Revisa el esquema SQL.` }, 500);
    }
    return response({ ok: true, user: { id: created.user.id, email, full_name: fullName, role, active } });
  } catch (error) {
    return response({ error: error instanceof Error ? error.message : 'Error inesperado al crear el usuario.' }, 500);
  }
});
