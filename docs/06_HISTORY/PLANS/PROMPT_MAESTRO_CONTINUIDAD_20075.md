# PROMPT MAESTRO DE CONTINUIDAD · KOMBAX RC13 build 20075

Trabaja desde KOMBAX RC13 build 20075 como candidata actual. No modificar ni sobrescribir builds anteriores.

Estado clave:
- GitHub y Netlify siguen PAUSADOS hasta autorización explícita.
- Supabase live tiene migraciones 119–130 aplicadas.
- `invite-email` v2 ACTIVE con JWT obligatorio.
- `health` v3 ACTIVE y responde HTTP 200 con build 20075 / db ok.
- Equipo: invitación nominativa por email `EQP-...`, ligada a email/club/rol, 7 días, un uso.
- Alumnos/familias: invitación nominativa por email `ALU-...`, ligada a email/club, 7 días, un uso.
- El flujo ALU valida código+email ANTES de crear una cuenta Auth.
- El código numérico general alumnos/familias continúa disponible y es distinto del ALU nominativo.
- Migración 130 corrigió el constraint legado que impedía `rol='alumno'` y separó unicidad pendiente por tipo de invitación.
- QA real ALU: correct email true, wrong email false, coexistencia con EQP PASS, residuos 0.
- Full npm test PASS; build parity 73 archivos `web = dist = Android`.
- Android preflight 4/5: solo falta firma release local.
- Release legal gate continúa intencionadamente bloqueado hasta completar datos legales/contactos finales.

Siguiente secuencia recomendada:
1. E2E real de emails: registro, recuperación, Owner OTP, invitación EQP y ALU.
2. Verificar remitente/plantillas KOMBAX y enlaces kombax.es.
3. Backup DB+Storage y restore drill real en destino aislado.
4. Completar legal/Child Safety.
5. Android signed APK/AAB + QA móvil.
6. Solo con autorización: GitHub PRIVATE → push → Netlify/kombax.es → QA desplegado → Google Play.

No marcar E2E email, restore, Android firmado ni publicación como PASS sin evidencia real.
