-- ============================================================================
-- Fundación PubliFuturo Colombia · Esquema de Supabase para sincronizar
-- la plataforma entre dispositivos.
--
-- CÓMO USAR:
-- 1. Entra a tu proyecto en supabase.com → menú lateral "SQL Editor".
-- 2. Pega TODO este archivo → botón "Run".
-- 3. Ve a "Project Settings" → "API" y copia:
--      - "Project URL"        → pégala en SUPABASE_URL dentro de index.html
--      - "anon public" (key)  → pégala en SUPABASE_ANON_KEY dentro de index.html
-- ============================================================================

-- Una sola tabla: guarda TODA la plataforma como un documento (igual a como
-- hoy se guarda en localStorage), en la fila con id = 'main'.
create table if not exists app_state (
  id text primary key,
  data jsonb not null,
  updated_by text,
  updated_at timestamptz not null default now()
);

-- Seguridad a nivel de fila (obligatoria en Supabase para tablas públicas)
alter table app_state enable row level security;

-- Esta demo no usa autenticación de usuarios (los 5 accesos son simulados
-- dentro de la propia app), así que la llave "anon" necesita permiso de
-- lectura y escritura sobre esta única fila.
--
-- ADVERTENCIA DE SEGURIDAD: como la llave "anon" vive en el HTML (es pública
-- por diseño en cualquier app de este tipo), cualquiera que tenga el enlace
-- del sitio y sepa llamar la API de Supabase podría leer o modificar estos
-- datos directamente, sin pasar por la interfaz. Para una fundación pequeña
-- operando de buena fe esto suele ser aceptable, pero si más adelante quieres
-- que cada rol necesite una contraseña real para escribir, se puede activar
-- Supabase Auth y policies por usuario — es un paso aparte, avísame cuando
-- lo quieras y lo preparamos.
drop policy if exists "allow anon read" on app_state;
drop policy if exists "allow anon insert" on app_state;
drop policy if exists "allow anon update" on app_state;

create policy "allow anon read" on app_state
  for select using (true);

create policy "allow anon insert" on app_state
  for insert with check (true);

create policy "allow anon update" on app_state
  for update using (true) with check (true);

-- Activa las actualizaciones en tiempo real (para que un cambio hecho desde
-- un celular aparezca al instante en un computador que tenga la página
-- abierta, sin necesidad de recargar).
alter publication supabase_realtime add table app_state;
