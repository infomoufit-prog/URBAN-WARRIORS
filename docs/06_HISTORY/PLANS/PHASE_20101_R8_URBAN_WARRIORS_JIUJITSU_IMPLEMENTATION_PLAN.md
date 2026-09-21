# KOMBAX 20.101 R8 · Urban Warriors Jiu-Jitsu Event · Implementation Plan

## Base
Base única: 20.101 R7 Gateway Atmospheric Hero. No se rehace ningún dominio y no se modifica el evento de ejemplo existente “Noche de Impacto · Barcelona”.

## Objetivo
Añadir un segundo KOMBAX Evento completo y ficticio, de tipo `interclub`, cuya identidad organizadora sea el club real Urban Warriors. Debe utilizar el dominio público normal de Events: organización, Fight Cards, participantes, inscripción, recinto, álbum y permisos de club.

## Arquitectura
1. Mantener `events.public.organize` como gate real.
2. Crear bootstrap Owner idempotente que resuelva Urban Warriors por slug/nombre, nunca por UUID generado.
3. Crear el evento como `creador_tipo='club'` + `creador_club_id=Urban Warriors`.
4. Vincular la entidad organizadora al perfil Social real de Urban Warriors cuando exista.
5. Crear 12 participantes ficticios y 6 combates reales de Fight Card.
6. Incluir categorías 8–10, 11–13, 14–15, 16–17 y adultos.
7. Incluir dos combates destacados: adulto masculino y adulto femenino.
8. Integrar 15 imágenes WEBP optimizadas. Sin vídeo.
9. Auto-instalar el evento y completar el álbum en el primer acceso Owner a KOMBAX Events; conservar botón manual de recuperación.
10. Mantener RLS/aislamiento y no tocar Mi Club > Eventos.

## Seguridad
- Bootstrap: Owner-only.
- Gestión posterior: reglas normales de Urban Warriors y entitlement Events.
- No se crea tabla o dominio paralelo.
- Nombres, clubes rivales y resultados son ficticios.
- No se publican datos reales de menores.
