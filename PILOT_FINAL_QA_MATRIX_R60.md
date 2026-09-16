# QA Matrix · KOMBAX R60 Pilot Final

| Gate | Resultado |
| --- | --- |
| npm test completo | PASS |
| npm run build | PASS |
| web = dist = Android | PASS · 197 archivos |
| release legal gate | PASS |
| Pilot Final Assist/Conversations | PASS 28/28 |
| R60 Migrations | PASS 32/32 |
| R38 Assist/Migrations | PASS 67/67 |
| R57 Social UX | PASS 25/25 |
| R56 perfil público | PASS 25/25 |
| R55 Events media architecture | PASS 26/26 |
| R55 Events load budget | PASS 5/5 |
| R54 Events mobile flow | PASS 14/14 |
| Android preflight | 4/5 · falta firma local |

## Validación manual recomendada antes del piloto con los tres clubes

1. Android físico: abrir 10 eventos consecutivos alternando Wi-Fi/datos y volver a cartelera, verificando scroll y ausencia de flashes/recargas completas.
2. Social: abrir Mensajes y confirmar que entra en capa independiente; abrir/cerrar conversación y volver al punto anterior.
3. Showcase: pulsar “Me interesa”, entrar en conversación contextual y volver al producto.
4. Álbumes: probar foto horizontal, vertical, cuadrada y vídeo vertical/horizontal en fullscreen.
5. Assist: validar Club, Federación y Marca con consultas de solo lectura y agotamiento de límite de mensajes en un tenant QA.
6. Migrations: carga mixta CSV/XLSX/PDF/imagen, análisis, preview y comprobación de que no existe importación automática.
7. Soporte KOMBAX: caso sin chat guiado, activación por Soporte en entorno QA, chat técnico y solicitud de revisión humana.
8. Tablet: verificar shell de conversaciones, composer sticky, Events y filtros sin overflow horizontal.
