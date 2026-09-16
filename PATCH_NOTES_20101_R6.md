# KOMBAX RC13 build 20.101 R6 - Events Discovery + Club Create Hardening

Fecha: 2026-08-27

## Problemas corregidos

### 1. El evento desaparecía al usar filtros
La cartelera combinaba silenciosamente el filtro temporal con el filtro por tipo. Por ejemplo, `Resultados + Velada` podía dejar la lista vacía. Además, volver a entrar en KOMBAX Events conservaba el filtro anterior porque el módulo permanecía cargado.

R6 cambia la experiencia:
- al entrar en KOMBAX Events se parte siempre de la cartelera completa;
- `Todos` limpia estado, tipo y búsqueda;
- se añade `Todos los tipos`;
- si una combinación no tiene resultados aparece `Mostrar todos los eventos`;
- el evento publicado nunca se borra por usar filtros: solo se filtra temporalmente.

### 2. Urban Warriors no mostraba `Crear evento`
El backend exige `events.public.organize`. Urban Warriors no tenía esa capacidad activa, por lo que el frontend ocultaba el botón de forma coherente con el contrato de permisos.

Se aplica la migración 179, idempotente y limitada al club piloto Urban Warriors:
- activa `events.public.organize` como promoción/piloto;
- no concede la capacidad a otros clubes;
- no concede ni mezcla identidades de federación;
- el aislamiento de workspace 20.097 permanece intacto.

El usuario con rol Dirección del club puede utilizar el editor real de eventos.

## Backend verificado
Evento de referencia:
- `Noche de Impacto · Barcelona`
- tipo: Velada
- fase temporal: Próximo
- estado: Inscripciones abiertas

Urban Warriors:
- `events.public.organize`: ACTIVO

## QA
- `npm run test:20101:r6`: PASS
- `npm run build`: PASS
- `npm run release:legal-gate`: PASS
- web = dist = Android: 132 archivos
- Android preflight: 4/5; únicamente falta `android/keystore.properties` local.
