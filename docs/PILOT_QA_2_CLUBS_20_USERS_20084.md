# QA piloto 20.084 · 2 clubes / ~20 usuarios

Matriz mínima:
- Club A y Club B: Dirección, Secretaría/Tesorería, Monitor, alumnos adultos y tutor/menor.
- Owner: acceso normal propio + soporte temporal A/B.
- Perfiles Social directos: al menos Federación/Competidor para comprobar no mezcla.

Pruebas bloqueantes:
- Sustituir club_id, socio_id, cuota_id, pago_id, recibo_id, documento_id, grupo_id, contacto_id y actor_social_id por IDs del otro club. Debe fallar o devolver 0 filas.
- Dos pestañas con clubes distintos; atrás/adelante; logout/login; caducidad y cambio de soporte.
- Pagos pendientes no cuentan como cobrado; recibo solo a saldo cero; recurrencia real bloqueada mientras Security Pilot=false.
- Storage privado: URL/path conocido de otro club no debe abrir.
- APK: deep links solo kombax.es, cleartext bloqueado, backup deshabilitado, WebView debug deshabilitado.
- PWA/Netlify: CSP/HSTS/frame/no-sniff/referrer/permissions y nuevos headers.

Criterio PASS: 0 cruces de tenant, 0 bypass Owner, 0 secreto cliente, 0 anomalías financieras bloqueantes.
