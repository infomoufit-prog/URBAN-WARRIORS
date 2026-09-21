# KOMBAX i18n · Formatting contract

Language and commercial/legal context are separate.

- `language`: UI language (`es`, `en`, `fr`, ...)
- `country`: commercial/geographic country
- `currency`: ISO currency such as `EUR`
- `timezone`: IANA timezone such as `Europe/Madrid`
- `jurisdiction`: legal jurisdiction

The i18n runtime centralizes BCP-47 locale tags and exposes number, currency, date, date-time, percent and plural formatting. Product code must not hardcode `es-ES`. Currency must be supplied independently and is never inferred solely from language.
