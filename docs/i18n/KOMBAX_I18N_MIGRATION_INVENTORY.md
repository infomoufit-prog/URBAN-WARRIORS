# KOMBAX i18n · Inventario de migraciones

## Preparadas, no desplegadas automáticamente

### 20260914230000_kombax_i18n_locale_preference_b01.sql
- Añade `preferred_locale` de forma aditiva.
- Restringe a locales soportados.
- Añade RPC autenticadas para lectura/escritura.
- No contiene DROP/TRUNCATE/DELETE destructivos.

### 20260914233000_kombax_i18n_legal_metadata_b03.sql
- Añade metadatos `locale`, `jurisdiction`, `legal_version`.
- Mantiene independencia entre idioma y jurisdicción.
- No convierte traducción en adaptación jurídica.
- No contiene DROP/TRUNCATE/DELETE destructivos.

## Política

Ninguna migración de este proyecto se despliega automáticamente desde el ZIP. Aplicar sólo mediante el procedimiento habitual de Supabase y validar RLS/RPC antes y después.
