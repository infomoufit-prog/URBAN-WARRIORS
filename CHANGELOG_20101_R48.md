# CHANGELOG · KOMBAX 20.101 R48

## Combat Events Premium Visual & Fight Card Experience

Base: R47 final preservada.

### Implementado
- Main Event rediseñado como nivel visual principal (`HEADLINER · COMBATE ESTELAR`) con marco premium, jerarquía tipográfica y glow cian/oro controlado.
- Co-Main Event incorporado como segundo nivel visual explícito (`CO-MAIN EVENT / COMBATE COESTELAR`), separado de la undercard.
- Fight Card completa estructurada con resumen de número de combates, Main, Co-Main y undercard.
- Nuevo cartel gráfico de la cartelera completa, pensado para veladas de Muay Thai/Kickboxing/Boxeo/MMA con todos los rostros en una sola pieza.
- El cartel de Fight Card reutiliza el álbum oficial existente como foto `previo`, con marcador semántico `[KOMBAX_FIGHT_CARD_POSTER]`; no se crea tabla, bucket ni cuota paralela.
- El cartel puede sustituirse de forma no destructiva: primero se sube el nuevo recurso y solo después se retira el anterior.
- El cartel permanece visible en el álbum oficial y puede abrirse con el visor fullscreen existente.
- Las fotografías individuales de peleadores continúan siendo opcionales; el layout mantiene fallback cuando faltan retratos.
- Constructor actualizado para presentar la jerarquía `Main · Co-Main · Fight Card` y comunicar si existe cartel completo.
- Gestor Fight Card ampliado con carga/retirada del cartel general de la velada.
- Álbum identifica el cartel de Fight Card con badge `CARTELERA`.
- Sistema visual R48: tipografía display condensada basada solo en fuentes locales/sistema, tipografía UI legible, cian Events, oro estelar y acentos atmosféricos controlados.
- Responsive específico para móvil y `prefers-reduced-motion`.
- Se preservan marcadores de compatibilidad para regresiones históricas sin mantener el diseño antiguo.

### Backend
R48 no necesita migración Supabase. Reutiliza contratos existentes ya verificados en vivo: Co-Main, límite de 30 combates, cuota de 30 fotos/5 vídeos, RLS del álbum y mutador autenticado.

### No realizado
- No se ha desplegado frontend en Netlify.
- No se ha hecho push a GitHub.
- No se ha generado APK/AAB firmada: falta `android/keystore.properties` local.
- No se ha ejecutado todavía, con sesión real autenticada de organizador, el ciclo subir → sustituir → retirar cartel en el backend vivo.
