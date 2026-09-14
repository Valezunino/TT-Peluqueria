
-- TT Peluquería. Run once in a dedicated Supabase project.
create extension if not exists btree_gist;
create table public.users(id uuid primary key references auth.users(id), role text not null default 'admin' check(role='admin'));
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from public.users where id=auth.uid())$$;
create table public.business_settings(
 id integer primary key check(id=1),name text not null,address text not null,whatsapp text not null,instagram text not null,
 price numeric(12,2) not null check(price>=0),duration integer not null check(duration between 10 and 180),
 enabled boolean not null default false,logo text not null default '',photos jsonb not null default '[]',
 check(not enabled or price>0),check(jsonb_typeof(photos)='array')
);
insert into public.business_settings values(1,'TT Peluquería','Dardo Rocha 626, Rojas, Buenos Aires','5492474472816','https://www.instagram.com/peluqueria_tt/',0,30,false,'','[]');
create table public.business_hours(id integer primary key check(id between 0 and 6),opens time not null,closes time not null,closed boolean not null,check(opens<closes));
-- Illustrative hours only. All days initially closed until owner configures them.
insert into public.business_hours select d,'09:00','19:00',true from generate_series(0,6) d;
create table public.customers(id uuid primary key default gen_random_uuid(),first_name text not null,last_name text not null,phone text not null unique,created_at timestamptz not null default now());
create table public.appointments(
 id uuid primary key default gen_random_uuid(),customer_id uuid not null references public.customers(id),
 starts_at timestamptz not null,ends_at timestamptz not null,status text not null default 'Reservado' check(status in('Reservado','Confirmado','Realizado','Cancelado','Ausente')),
 price numeric(12,2) not null check(price>=0),created_at timestamptz not null default now(),check(ends_at>starts_at),
 exclude using gist(tstzrange(starts_at,ends_at,'[)') with &&) where(status in('Reservado','Confirmado','Realizado'))
);
create index appointments_customer on public.appointments(customer_id);
create table public.payments(id uuid primary key default gen_random_uuid(),appointment_id uuid not null unique references public.appointments(id),customer_id uuid not null references public.customers(id),paid_at timestamptz not null default now(),amount numeric(12,2) not null check(amount>=0),method text not null check(method in('Efectivo','Transferencia','Mercado Pago','Tarjeta','Otro')),customer_name text not null);
create index payments_date on public.payments(paid_at);
create table public.blocked_times(id uuid primary key default gen_random_uuid(),starts_at timestamptz not null,ends_at timestamptz not null,reason text not null,check(ends_at>starts_at));
create table public.notifications(id uuid primary key default gen_random_uuid(),appointment_id uuid not null references public.appointments(id),created_at timestamptz not null default now(),read_at timestamptz,payload jsonb not null);
-- Durable outbox for future email, WhatsApp and push workers. No external sending is configured.
create table public.notification_outbox(id uuid primary key default gen_random_uuid(),notification_id uuid not null references public.notifications(id),channel text not null,status text not null default 'pending',attempts integer not null default 0,created_at timestamptz not null default now());
create table public.audit_log(id uuid primary key default gen_random_uuid(),actor uuid,action text not null,appointment_id uuid,created_at timestamptz not null default now(),details jsonb);

alter table public.users enable row level security;
alter table public.business_settings enable row level security;
alter table public.business_hours enable row level security;
alter table public.customers enable row level security;
alter table public.appointments enable row level security;
alter table public.payments enable row level security;
alter table public.blocked_times enable row level security;
alter table public.notifications enable row level security;
alter table public.notification_outbox enable row level security;
alter table public.audit_log enable row level security;
create policy self_read on public.users for select to authenticated using(id=auth.uid());
create policy public_settings on public.business_settings for select to anon,authenticated using(true);
create policy public_hours on public.business_hours for select to anon,authenticated using(true);
create policy admin_customers on public.customers for select to authenticated using(public.is_admin());
create policy admin_appointments on public.appointments for select to authenticated using(public.is_admin());
create policy admin_payments on public.payments for select to authenticated using(public.is_admin());
create policy admin_blocks on public.blocked_times for select to authenticated using(public.is_admin());
create policy admin_notifications on public.notifications for select to authenticated using(public.is_admin());
create policy admin_outbox on public.notification_outbox for select to authenticated using(public.is_admin());
create policy admin_audit on public.audit_log for select to authenticated using(public.is_admin());
revoke all on public.users,public.customers,public.appointments,public.payments,public.blocked_times,public.notifications,public.notification_outbox,public.audit_log,public.business_settings,public.business_hours from anon,authenticated;
grant select on public.business_settings,public.business_hours to anon,authenticated;
grant select on public.users,public.customers,public.appointments,public.payments,public.blocked_times,public.notifications,public.notification_outbox,public.audit_log to authenticated;

create function public.available_slots(p_day date) returns table(starts_at timestamptz) language plpgsql security definer set search_path=public as $$
declare s public.business_settings;h public.business_hours;
begin
 select * into s from public.business_settings where id=1;
 if not s.enabled or p_day<(now() at time zone 'America/Argentina/Buenos_Aires')::date or p_day>(now() at time zone 'America/Argentina/Buenos_Aires')::date+90 then return;end if;
 select * into h from public.business_hours where id=extract(dow from p_day);
 if h.closed then return;end if;
 return query select slot from generate_series(
 (p_day+h.opens) at time zone 'America/Argentina/Buenos_Aires',
 ((p_day+h.closes) at time zone 'America/Argentina/Buenos_Aires')-make_interval(mins=>s.duration),
 make_interval(mins=>s.duration)) slot
 where slot>now()
 and not exists(select 1 from public.appointments a where a.status in('Reservado','Confirmado','Realizado') and tstzrange(a.starts_at,a.ends_at,'[)') && tstzrange(slot,slot+make_interval(mins=>s.duration),'[)'))
 and not exists(select 1 from public.blocked_times b where tstzrange(b.starts_at,b.ends_at,'[)') && tstzrange(slot,slot+make_interval(mins=>s.duration),'[)'));
end$$;

create function public.book_appointment(p_start timestamptz,p_first text,p_last text,p_phone text,p_price numeric) returns uuid language plpgsql security definer set search_path=public as $$
declare s public.business_settings;c uuid;a uuid;n uuid;v_phone text;data jsonb;
begin
 perform pg_advisory_xact_lock(7262026);
 v_phone:=regexp_replace(p_phone,'[^0-9]','','g');
 if length(trim(p_first)) not between 2 and 60 or length(trim(p_last)) not between 2 and 60 or length(v_phone) not between 10 and 15 then raise exception 'Revisá el nombre, apellido y teléfono.';end if;
 if p_first is null or p_last is null or p_phone is null or p_start is null then raise exception 'Completá todos los campos.';end if;
 select * into s from public.business_settings where id=1;
 if p_price is distinct from s.price then raise exception 'El precio cambió. Actualizá la página antes de reservar.';end if;
 if not exists(select 1 from public.available_slots((p_start at time zone 'America/Argentina/Buenos_Aires')::date) x where x.starts_at=p_start) then raise exception 'Este horario ya no está disponible.';end if;
 if (select count(*) from public.appointments a join public.customers c on c.id=a.customer_id where c.phone=v_phone and a.created_at>now()-interval '24 hours')>=3 then raise exception 'Límite de reservas alcanzado. Contactá a la peluquería.';end if;
 -- Do not allow public callers to overwrite an existing customer's identity.
 insert into public.customers(first_name,last_name,phone) values(trim(p_first),trim(p_last),v_phone) on conflict do nothing returning id into c;
 if c is null then select id into c from public.customers where customers.phone=v_phone;end if;
 insert into public.appointments(customer_id,starts_at,ends_at,price) values(c,p_start,p_start+make_interval(mins=>s.duration),s.price) returning id into a;
 data:=jsonb_build_object('name',trim(p_first)||' '||trim(p_last),'phone',v_phone,'starts_at',p_start,'price',s.price);
 insert into public.notifications(appointment_id,payload) values(a,data) returning id into n;
 insert into public.audit_log(action,appointment_id,details) values('reserved',a,jsonb_build_object('notification_id',n));
 return a;
end$$;

create function public.admin_action(p_action text,p_data jsonb default '{}') returns void language plpgsql security definer set search_path=public as $$
declare a public.appointments;s public.business_settings;h jsonb;new_start timestamptz;new_end timestamptz;new_price numeric;new_status text;
begin
 if not public.is_admin() then raise exception 'Acceso denegado';end if;
 perform pg_advisory_xact_lock(7262026);
 if p_action='settings' then
  if length(trim(p_data->>'name')) not between 2 and 100 then raise exception 'Nombre inválido';end if;
  update public.business_settings set name=trim(p_data->>'name'),address=p_data->>'address',whatsapp=p_data->>'whatsapp',instagram=p_data->>'instagram',price=(p_data->>'price')::numeric,duration=(p_data->>'duration')::integer,enabled=(p_data->>'enabled')::boolean,logo=coalesce(p_data->>'logo',''),photos=coalesce(p_data->'photos','[]') where id=1;
 elsif p_action='hours' then
  for h in select * from jsonb_array_elements(p_data->'hours') loop
   update public.business_hours set opens=(h->>'opens')::time,closes=(h->>'closes')::time,closed=(h->>'closed')::boolean where id=(h->>'id')::integer;
  end loop;
 elsif p_action='block' then
  new_start:=(p_data->>'starts_at')::timestamptz;new_end:=(p_data->>'ends_at')::timestamptz;
  if exists(select 1 from public.appointments where status in('Reservado','Confirmado') and tstzrange(starts_at,ends_at,'[)') && tstzrange(new_start,new_end,'[)')) then raise exception 'Hay turnos en ese período. Reprogramalos o cancelalos primero.';end if;
  insert into public.blocked_times(starts_at,ends_at,reason) values(new_start,new_end,p_data->>'reason');
 elsif p_action='unblock' then delete from public.blocked_times where id=(p_data->>'id')::uuid;
 elsif p_action='read' then update public.notifications set read_at=now() where read_at is null;
 else
  select * into a from public.appointments where id=(p_data->>'id')::uuid for update;
  if not found then raise exception 'Turno no encontrado';end if;
  if a.status='Realizado' then
   if p_action='complete' then return;end if;
   raise exception 'Un corte cobrado conserva su historial y no puede modificarse.';
  end if;
  if p_action='complete' then
   if a.status not in('Reservado','Confirmado') then raise exception 'Este turno no se puede cobrar.';end if;
   if a.starts_at>now() then raise exception 'No se puede cobrar un turno futuro.';end if;
   new_price:=(p_data->>'price')::numeric;
   insert into public.payments(appointment_id,customer_id,amount,method,customer_name) select a.id,a.customer_id,new_price,p_data->>'method',first_name||' '||last_name from public.customers where id=a.customer_id;
   update public.appointments set status='Realizado',price=new_price where id=a.id;
  elsif p_action='status' then
   new_status:=p_data->>'status';
   if new_status not in('Confirmado','Cancelado','Ausente') or new_status is null then raise exception 'Estado inválido';end if;
   if a.status not in('Reservado','Confirmado') then raise exception 'El turno ya está cerrado.';end if;
   if new_status='Ausente' and a.starts_at>now() then raise exception 'El turno todavía no comenzó.';end if;
   update public.appointments set status=new_status where id=a.id;
  elsif p_action='reschedule' then
   if a.status not in('Reservado','Confirmado') then raise exception 'El turno ya está cerrado.';end if;
   new_start:=(p_data->>'starts_at')::timestamptz;
   if new_start is null then raise exception 'Seleccioná un horario';end if;
   -- Temporarily release own slot inside this transaction to permit overlap with its old range.
   update public.appointments set status='Cancelado' where id=a.id;
   if not exists(select 1 from public.available_slots((new_start at time zone 'America/Argentina/Buenos_Aires')::date) x where x.starts_at=new_start) then raise exception 'Horario no disponible';end if;
   select * into s from public.business_settings where id=1;
   update public.appointments set starts_at=new_start,ends_at=new_start+make_interval(mins=>s.duration),status=a.status where id=a.id;
  elsif p_action='price' then update public.appointments set price=(p_data->>'price')::numeric where id=a.id;
  else raise exception 'Acción inválida';
  end if;
 end if;
 insert into public.audit_log(actor,action,appointment_id,details) values(auth.uid(),p_action,a.id,p_data-'logo'-'photos');
end$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;
revoke all on function public.available_slots(date) from public;
revoke all on function public.book_appointment(timestamptz,text,text,text,numeric) from public;
revoke all on function public.admin_action(text,jsonb) from public;
grant execute on function public.available_slots(date),public.book_appointment(timestamptz,text,text,text,numeric) to anon,authenticated;
grant execute on function public.admin_action(text,jsonb) to authenticated;
