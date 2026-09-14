\set ON_ERROR_STOP on
begin;
insert into auth.users values('00000000-0000-0000-0000-000000000001'),('00000000-0000-0000-0000-000000000002');
insert into public.users values('00000000-0000-0000-0000-000000000001','admin');
update business_settings set enabled=true,price=15000;
update business_hours set closed=false;
create temporary table test_ids(id uuid,slot timestamptz);
do $$
declare slot timestamptz;a uuid;count_rows integer;
begin
 select starts_at into slot from available_slots((now() at time zone 'America/Argentina/Buenos_Aires')::date+1) limit 1;
 if slot is null then raise exception 'Expected an available slot';end if;
 a:=book_appointment(slot,'Juan','Pérez','2474000000',15000);
 insert into test_ids values(a,slot);
 if exists(select 1 from available_slots((slot at time zone 'America/Argentina/Buenos_Aires')::date) x where x.starts_at=slot) then raise exception 'Booked slot still available';end if;
 begin perform book_appointment(slot,'Ana','García','2474000001',15000);raise exception 'Duplicate accepted';exception when raise_exception then if sqlerrm='Duplicate accepted' then raise;end if;end;
 if (select count(*) from payments)<>0 then raise exception 'Reservation generated revenue';end if;
 if (select count(*) from notifications)<>1 then raise exception 'Missing notification';end if;
end$$;
set local role anon;
do $$begin
 begin perform * from public.customers;raise exception 'Anonymous customer leak';exception when insufficient_privilege then null;end;
 begin perform public.admin_action('read');raise exception 'Anonymous admin access';exception when insufficient_privilege then null;end;
end$$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
set local role authenticated;
do $$begin
 if (select count(*) from customers)<>0 then raise exception 'Non-admin customer leak';end if;
 begin perform admin_action('read');raise exception 'Non-admin action accepted';exception when raise_exception then if sqlerrm='Non-admin action accepted' then raise;end if;end;
end$$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
do $$declare a uuid;s timestamptz;
begin
 select id,slot into a,s from test_ids;
 begin perform admin_action('complete',jsonb_build_object('id',a,'price',15000,'method','Efectivo'));raise exception 'Future payment accepted';exception when raise_exception then if sqlerrm='Future payment accepted' then raise;end if;end;
 begin perform admin_action('block',jsonb_build_object('starts_at',s,'ends_at',s+interval '1 hour','reason','Test'));raise exception 'Overlapping block accepted';exception when raise_exception then if sqlerrm='Overlapping block accepted' then raise;end if;end;
 -- Fixture: represent a visit that has already taken place.
 update appointments set starts_at=now()-interval '1 hour',ends_at=now()-interval '30 minutes' where id=a;
 perform admin_action('complete',jsonb_build_object('id',a,'price',14500,'method','Efectivo'));
 perform admin_action('complete',jsonb_build_object('id',a,'price',14500,'method','Efectivo'));
 if (select count(*) from payments)<>1 or (select sum(amount) from payments)<>14500 then raise exception 'Payment not idempotent';end if;
 begin perform admin_action('status',jsonb_build_object('id',a,'status','Cancelado'));raise exception 'Paid visit altered';exception when raise_exception then if sqlerrm='Paid visit altered' then raise;end if;end;
end$$;
rollback;
