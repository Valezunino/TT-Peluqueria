# TT Peluquería

Web de reservas de cortes y administración para TT Peluquería, Rojas. Next.js App Router, React, TypeScript, Tailwind CSS, Supabase/PostgreSQL y gráficos Recharts.

## Iniciar

1. Usar Node.js 22.
2. Ejecutar `npm install`.
3. Copiar `.env.example` a `.env.local` y completar las variables públicas de Supabase.
4. Aplicar la migración y asignar el administrador siguiendo [DEPLOYMENT.md](DEPLOYMENT.md).
5. Ejecutar `npm run dev`. Web en `/`; panel en `/admin`.

## Incluye

- Reserva: fecha, horario disponible, nombre, apellido y teléfono; resumen del corte y precio.
- Exclusión de intervalos en PostgreSQL y transacción serializada para evitar reservas superpuestas.
- Roles administrativos mediante Supabase Auth y RLS. Los clientes no necesitan crear cuenta.
- Agenda día, semana (7 días desde la fecha seleccionada) y mes; confirmar, cancelar, reprogramar, ausente, editar precio y cobrar.
- Cobro atómico e idempotente con importe histórico y método de pago. Un turno cobrado queda inmutable.
- Caja por día, semana, mes, mes anterior y rango; historial filtrable y clientes con visitas y gasto acumulado.
- Gráficos diarios y mensuales, medios de pago, horarios demandados y clientes frecuentes.
- Notificaciones persistentes, contador y alerta visual con actualización cada 15 segundos mientras el panel está abierto.
- Configuración de precio, duración, datos, logo/fotos, horarios y bloqueos.
- Registro de auditoría; tabla outbox para ampliar notificaciones. No se envía WhatsApp, email ni push automáticamente.

## Configuración pendiente antes de abrir al público

- Proyecto Supabase propio de la peluquería y administrador.
- Precio y horarios reales: las reservas vienen deshabilitadas y todos los días cerrados como medida inicial.
- Cargar el logo original y fotos reales desde Configuración. Los adjuntos del chat no están incorporados al repositorio; se muestra una marca tipográfica provisional.
- Despliegue en Vercel y prueba real entre dos dispositivos.
- Configurar protección de abuso adicional (p. ej. CAPTCHA validado en servidor y limitación por IP) antes de campañas con mucho tráfico. La base incluye límite de 3 reservas por teléfono cada 24 horas, que no protege frente a teléfonos inventados.
- Configurar copias de seguridad según el plan contratado: no hay borrado de historial desde la app, pero eso no sustituye un backup.

## Criterios de datos

Zona horaria: America/Argentina/Buenos_Aires. Importes ARS. Caja, totales mensuales y gráficos de ingresos usan **fecha de cobro**. Primera y última visita usan la fecha de los turnos realizados. Promedios mensuales usan días calendario transcurridos. La tarifa se copia al reservar; cambiarla no altera reservas previas.

Número de teléfono normalizado a dígitos para deduplicación. Clientes ya existentes conservan su identidad original: una reserva pública no puede cambiar sus datos.

## Verificación

`npm run typecheck`, `npm test`, `npm run build`. GitHub Actions además crea un PostgreSQL aislado y comprueba RLS, rechazo de solapamientos, cobro idempotente y conservación del historial.

Los scripts `tests/bootstrap.sql` y `tests/database.sql` son exclusivamente para CI, nunca para el proyecto Supabase de producción.
