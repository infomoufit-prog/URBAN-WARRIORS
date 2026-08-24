Continúa KOMBAX desde RC13 build 20077 como fuente de verdad local.

Prioridades:
1. No desplegar GitHub ni Netlify hasta autorización explícita.
2. Mantener acceso Owner: entrada oculta + cuenta Owner + contraseña -> sesión admin 30 min. No OTP cotidiano.
3. Mantener OTP solo para elevación crítica/destructiva (p. ej. eliminación irreversible de cuenta/borrado profundo).
4. Preservar Data Lifecycle + KOMBAX Analytics + retención/purga de 20077.
5. Antes de deploy: QA E2E visual Owner real, correo/auth E2E, backup/restore real, legal placeholders, Android signed APK/AAB y QA físico.
6. No afirmar GO producción hasta cerrar los gates pendientes con evidencia.

Validación específica Owner: BUILD_20077_OWNER_ACCESS_VALIDATION.md

## Añadido · Owner Support Mode (migration 140)
- Urban Warriors conserva la membresía real del Owner como Dirección/Gestor.
- Para cualquier otro Club: Owner → Entidades → motivo → MODO SOPORTE KOMBAX; no se crea membresía.
- Para Marca/Federación/Competidor: scope temporal `owner_support`; no cambia owner ni se crea gestor.
- Banner visible de soporte + salida explícita a Consola Owner.
- Acceso ligado a Owner session + entity session y auditado.
- Cuentas individuales: administración Owner sin suplantación de identidad ni contraseña.
