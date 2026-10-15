-- ═════════════════════════════════════════════════════════════════════
--  PUBLIFUTURO · Seguridad de Supabase
--  Ejecutar por PARTES y EN ORDEN en SQL Editor.
--  La PARTE B va AL FINAL, solo después de comprobar el paso 6 de la guía.
-- ═════════════════════════════════════════════════════════════════════


-- ───────── PARTE A · Funciones públicas (se puede ejecutar ya) ─────────
-- Dejan que el portal del cliente y el verificador de certificados sigan
-- funcionando SIN sesión, devolviendo únicamente los datos seguros.

create or replace function public.get_public_project(tok text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  st jsonb;
  m  jsonb;
begin
  if tok is null or length(tok) < 12 then return null; end if;   -- solo tokens largos, nunca IDs
  select data into st from app_state where id = 'main';
  if st is null then return null; end if;

  select e into m
    from jsonb_array_elements(coalesce(st->'microapps', '[]'::jsonb)) e
   where e->>'token' = tok
   limit 1;
  if m is null then return null; end if;

  return jsonb_build_object(
    'id', m->'id', 'empresa', m->'empresa', 'cliente', m->'cliente',
    'tipo', m->'tipo', 'categoria', m->'categoria', 'estado', m->'estado',
    'fechaInicio', m->'fechaInicio', 'entregaEst', m->'entregaEst',
    'mantenimiento', m->'mantenimiento', 'url', m->'url',
    'precio', m->'precio', 'pagado', m->'pagado', 'saldo', m->'saldo',
    'subs', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', s->'id', 'servicio', s->'servicio', 'modalidad', s->'modalidad',
               'diaCobro', s->'diaCobro', 'valorMensual', s->'valorMensual',
               'valorAnual', s->'valorAnual', 'inicio', s->'inicio', 'estado', s->'estado',
               'pagos', coalesce(s->'pagos', '[]'::jsonb)))
        from jsonb_array_elements(coalesce(st->'subs', '[]'::jsonb)) s
       where s->>'unidad' = 'microapps' and s->>'cliente' = m->>'cliente'
    ), '[]'::jsonb)
  );
end $$;

create or replace function public.verify_certificate(code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  st jsonb;
  s  jsonb;
  c  text;
begin
  c := upper(trim(coalesce(code, '')));
  if c !~ '^PF-2026-[A-Z0-9]+$' then return null; end if;
  select data into st from app_state where id = 'main';
  if st is null then return null; end if;

  select e into s
    from jsonb_array_elements(coalesce(st->'students', '[]'::jsonb)) e
   where e->>'estado' = 'Certificado'
     and ('PF-2026-' || upper(e->>'id')) = c
   limit 1;
  if s is null then return null; end if;

  return jsonb_build_object('id', s->'id', 'nombre', s->'nombre',
                            'cursoId', s->'cursoId', 'grupoId', s->'grupoId');
end $$;

grant execute on function public.get_public_project(text) to anon, authenticated;
grant execute on function public.verify_certificate(text)  to anon, authenticated;


-- ───────── PARTE B · Cerrar la tabla (EJECUTAR AL FINAL) ─────────
-- Solo entra a los datos quien tenga una sesión nacida de un CÓDIGO al correo.
-- Una sesión de solo contraseña no sirve.

create or replace function public.session_has_email_code()
returns boolean
language sql
stable
as $$
  select exists (
    select 1
      from jsonb_array_elements(coalesce(auth.jwt() -> 'amr', '[]'::jsonb)) a
     where coalesce(a ->> 'method', a #>> '{}') in ('otp', 'magiclink')
  );
$$;

drop policy if exists "Allow read"   on app_state;
drop policy if exists "Allow update" on app_state;
drop policy if exists "Allow insert" on app_state;
drop policy if exists "estado_leer"       on app_state;
drop policy if exists "estado_actualizar" on app_state;
drop policy if exists "estado_insertar"   on app_state;

create policy "estado_leer" on app_state
  for select to authenticated using (public.session_has_email_code());

create policy "estado_actualizar" on app_state
  for update to authenticated
  using (public.session_has_email_code()) with check (public.session_has_email_code());

create policy "estado_insertar" on app_state
  for insert to authenticated with check (public.session_has_email_code());

revoke all on table public.app_state from anon;


-- ───────── ROLLBACK · solo si algo sale mal tras la PARTE B ─────────
-- Vuelve a abrir la tabla como estaba (úsalo únicamente en emergencia).
--
-- drop policy if exists "estado_leer"       on app_state;
-- drop policy if exists "estado_actualizar" on app_state;
-- drop policy if exists "estado_insertar"   on app_state;
-- grant select, insert, update on table public.app_state to anon;
-- create policy "Allow read"   on app_state for select using (true);
-- create policy "Allow update" on app_state for update using (true);
-- create policy "Allow insert" on app_state for insert with check (true);
