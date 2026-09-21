# KOMBAX R80 · build 20132 — Finance / Stripe / SEPA hotfix

Fecha: 18/09/2026
Base: R80 build 20131 ordenada y acumulativa.
Resultado: hotfix acumulativo R80 build 20132.

## Incidencia reproducida

En `Mi Club → Finanzas` el acceso **Gestionar cobros** podía terminar en el aviso genérico “No se ha podido completar la operación”, y Tarjeta / Domiciliación SEPA no estaban visibles directamente en el resumen.

## Causa raíz

El frontend R80 estaba desplegado mientras el Supabase de producción aún no contenía los RPC/tablas/función Edge correspondientes a la fase R80 de Stripe/SEPA. El problema era, por tanto, una **desalineación de despliegue frontend ↔ backend**, no una rotura del motor histórico de generación de cargos.

Se verificó además `Nuevo cargo` mediante la función de *preview/shadow* en producción sin escribir cargos: la previsualización devolvió correctamente destinatario, importe y periodo. No se creó ningún cargo real durante el diagnóstico.

## Correcciones de código

- Build incrementado a **20132** para invalidar caché web/PWA/Android.
- `Finanzas → Resumen` muestra ahora un bloque premium visible de métodos de cobro.
- **Cobros con tarjeta** y **Domiciliación bancaria SEPA** muestran estado y acción de forma independiente.
- `Gestionar cobros` se conserva como acceso secundario.
- Si el backend R80 no estuviera disponible, se muestra un estado explícito de backend pendiente y se bloquean acciones incompatibles en vez de devolver un error genérico.
- Las cuentas Connect existentes solicitan la capacidad `sepa_debit_payments` al volver a completar onboarding.
- Se mantienen Direct Charges y una única cuenta Connect por identidad comercial.

## Backend R80 aplicado a Supabase

Se aplicó de forma aditiva y controlada el esquema R80: preferencias independientes Tarjeta/SEPA, Customers por cuenta Connect, mandatos SEPA, estados asíncronos, pagador/tutor, conciliación y RPC de lectura/gestión.

Funciones Edge activas tras el hotfix:
- `stripe-connect` v8 — JWT requerido.
- `stripe-sepa` v1 — JWT requerido.
- `stripe-webhook` v7 — autenticación por firma Stripe, sin JWT de usuario.

No se ejecutó ningún adeudo, cargo, mandato real ni movimiento de fondos.

## Urban Warriors

La cuenta Connect existente está registrada, pero Stripe la mantiene actualmente en estado restringido por requisitos de onboarding pendientes. Por ello Tarjeta, SEPA y payouts no pueden marcarse como operativos hasta completar esos requisitos en Stripe. KOMBAX debe mostrar ese estado y dirigir al usuario al onboarding, en lugar de simular que los métodos están activos.

## Validación

- Test específico hotfix: **9/9 PASS**.
- Regresión acumulativa `npm test`: **PASS** (ejecutada tras la modificación final de Connect).
- Build determinista: **465 archivos · web = dist = Android**.
- Android preflight: **4/5**; único pendiente `android/keystore.properties` local, no distribuible.
- Escaneo: 0 claves Stripe live; 0 `.env` reales; 0 keystore/JKS privados.
- RLS de tablas financieras R80: deny-by-default, acceso vía service-role/RPC controlado.

## Despliegue

El **backend Supabase R80 sí quedó actualizado** durante este hotfix. El frontend 20132 no se publicó automáticamente en Netlify desde este entorno porque la conexión Netlify disponible no expone el proyecto KOMBAX. El ZIP 20132 contiene el frontend corregido listo para el despliegue habitual de KOMBAX.
