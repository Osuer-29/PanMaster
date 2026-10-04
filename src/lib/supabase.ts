import { createClient } from '@supabase/supabase-js';
const url = (import.meta.env.VITE_SUPABASE_URL as string | undefined)?.trim();
const key = (import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined)?.trim();
function validUrl(value: string | undefined): boolean {
  try { return Boolean(value && new URL(value).protocol === 'https:'); }
  catch { return false; }
}
export const isSupabaseConfigured = Boolean(validUrl(url) && key);
// Una configuración inválida debe mostrar la pantalla de configuración,
// no fallar durante la importación antes de montar React.
export const supabase = createClient(
  isSupabaseConfigured ? url! : 'https://placeholder.supabase.co',
  isSupabaseConfigured ? key! : 'placeholder-anon-key',
);
