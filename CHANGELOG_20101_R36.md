# KOMBAX 20.101 R36 · Event Links + Fighter Discovery

## Objetivo
R36 conecta de forma explícita y opcional los eventos privados de **Mi Club** con fichas existentes de **KOMBAX Events**, sin convertir la conexión en una sincronización automática. Añade además **Fighter Discovery & Fight Invitations** para localizar competidores adultos que voluntariamente se declaren disponibles para oportunidades deportivas.

## Conexión de eventos
- Mi Club → Evento → **KOMBAX Events** abre el gestor de conexión.
- La relación es uno-a-uno, voluntaria, pausable y reversible.
- Conectar no publica información automáticamente.
- Política granular: datos generales, horario, ubicación, visuales, organizadores, categorías, participantes, Fight Card, pesaje oficial, resultados, álbum y highlights.
- Todos los flags de publicación nacen en `false`.
- Se genera una proyección pública limitada a los bloques autorizados.
- Auditoría de conexión, estado, política y publicación.

## Privacidad multiclub y peso
- R36 no consulta `kombax_weight_measurements_v216` ni `kombax_competition_preparations_v216` desde las APIs de conexión o discovery.
- El histórico privado R35 sigue aislado por club/preparación.
- El pesaje oficial es un bloque independiente y opt-in para publicación.
- Conexión de evento != acceso a datos privados del otro club.

## Fighter Discovery
- Solo perfiles directos `competidor` adultos con fecha de nacimiento verificada pueden activar descubrimiento abierto.
- Opt-in: `discoverable=false` por defecto.
- Disponibilidad: disponible, short notice, limitada o no disponible.
- Vía de contacto: directo, club, manager/representante o ambas.
- Búsqueda por disciplina, categoría, rango competitivo declarado, nivel, territorio y short notice.
- El rango competitivo público no es el peso actual ni el historial de preparación.
- KOMBAX Social incorpora acceso al buscador de peleadores y al perfil público/contacto.
- KOMBAX Events incorpora **Buscar sustituto / rival**.

## Invitaciones
- Flujo: Buscar → Invitar → Aceptar/Rechazar → Confirmar inscripción.
- Aceptar no crea automáticamente la inscripción.
- El competidor gestiona invitaciones desde **Oportunidades de combate**.
- Menores quedan fuera del discovery abierto.

## Backend
Migraciones nuevas:
- `220_kombax_event_connections_publication_r36.sql`
- `221_kombax_fighter_discovery_invitations_r36.sql`
- `222_kombax_r36_privacy_audit_hardening.sql`

Las tres fueron aplicadas al proyecto Supabase de continuidad y verificadas.
