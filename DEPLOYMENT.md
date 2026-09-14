# Puesta en marcha

## 1. Base de datos propia

Crear o elegir un proyecto Supabase exclusivo para TT Peluquería. No usar las tablas de otros clientes. Revisar el costo en la cuenta antes de contratar o crear recursos pagos.

En SQL Editor ejecutar una sola vez `supabase/migrations/001_initial.sql`. La migración no borra tablas existentes; requiere un proyecto nuevo sin tablas con estos nombres.

En Authentication crear un usuario con email y contraseña segura. No guardar la contraseña en GitHub. Copiar el UUID de ese usuario y ejecutar, reemplazando el marcador:

```sql
insert into public.users(id, role) values ('UUID-DEL-USUARIO', 'admin');
```

Deshabilitar registro público por email si no se necesita. Los clientes reservan sin cuenta. Ningún usuario obtiene rol admin por registrarse: requiere la asignación anterior.

## 2. Variables

Configurar localmente en `.env.local` o en Vercel:
- `NEXT_PUBLIC_SUPABASE_URL`: URL del proyecto.
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`: clave publicable o anon del proyecto.

Estas claves están pensadas para frontend: la seguridad la establecen RLS y las funciones SQL. **Nunca colocar service_role, secret keys ni contraseña de PostgreSQL en estas variables.** No se requiere service_role en esta aplicación.

## 3. Vercel

Importar Valezunino/TT-Peluqueria, seleccionar Next.js, Node 22 y configurar las dos variables. Build: `npm run build`. Publicar la rama main tras comprobar la verificación. Configurar el dominio de producción en Supabase Authentication / URL Configuration.

## 4. Configuración del negocio

Abrir /admin e ingresar con el usuario creado.

1. Guardar los horarios reales de martes a sábado. Lunes y domingo cerrados, según información suministrada. Los intervalos iniciales 09:00–19:00 son solo valores de formulario y están cerrados.
2. Configurar precio y duración. No hay precio real confirmado, por eso empieza en 0.
3. Cargar el logo original y hasta 6 fotos JPG/PNG/WebP de máximo 800 KB cada una. Se guardan en la configuración pública; usar únicamente imágenes del negocio.
4. Confirmar dirección, Instagram y WhatsApp.
5. Habilitar reservas.

## 5. Prueba antes de compartir el enlace

- Abrir en celular y reservar un horario futuro.
- Intentar reservar ese mismo horario desde otro navegador: debe desaparecer o ser rechazado.
- Comprobar que la reserva no aumente Caja y que aparezca la notificación.
- Confirmar/reprogramar/cancelar y probar un bloqueo sin turnos existentes.
- Al realizar el corte, seleccionar medio de pago y marcar Realizado / Cobrado. Revisar Caja e Historial; repetir no debe duplicar el pago.
- Cerrar sesión y comprobar que los datos del panel dejan de verse. Un usuario sin rol admin no debe acceder.
- Comprobar cambio de día/mes en hora argentina.

No se probaron dispositivos físicos desde esta sesión. La verificación automatizada no reemplaza esta prueba operativa.

## Notificaciones externas y persistencia

La app muestra notificaciones por consulta periódica cada 15 segundos. Para WhatsApp/email/push, agregar un proveedor y un worker que consuma notification_outbox con reintentos e idempotencia; la tabla está preparada pero aún no se generan envíos externos.

Los turnos, pagos y auditoría se conservan en PostgreSQL. Configurar respaldos y monitoreo según necesidades. No hay carga de datos ficticios ni una cuenta administrativa con contraseña fija.
