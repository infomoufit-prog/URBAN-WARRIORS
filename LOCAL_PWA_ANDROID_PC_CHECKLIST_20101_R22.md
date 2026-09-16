# Checklist local R22 · PC / PWA / Android

## PC · Chrome local
1. Descomprimir R22 en carpeta nueva.
2. Abrir CMD en la raíz donde existe `package.json`.
3. Ejecutar `npm ci` y después `npm run dev` (usar `npm install` solo si el lockfile impide `npm ci`).
4. Abrir la URL local exacta indicada por el terminal.

### Events · fluidez
- Entrar/salir de Events varias veces.
- Abrir Barcelona/Urban/seminario y volver atrás.
- Confirmar que la lista no hace reconstrucciones largas perceptibles al volver.
- Scroll rápido: observar que no aparezcan flashes negros en cards/álbum.
- Usar búsqueda y filtros varias veces; no deben mezclarse resultados de una búsqueda anterior.
- Pulsar `Cargar más eventos`; comprobar que se añaden elementos y no se duplican los anteriores.

### Fight Card
- Main Event aparece antes de la cartelera secundaria.
- Main Event es visualmente mayor y promocional.
- Co-Main aparece segundo cuando está configurado.
- Undercard es más compacta.
- Editar/crear combate: límites y roles Main/Co-Main coherentes.

### Media
- Álbum muestra máximo lógico 30 fotos.
- Fotos de peleadores no descuentan álbum por existir como participantes.
- Cartel/banner no descuentan álbum por existir.
- Probar `Añadir al álbum` sobre cartel/banner/foto de participante.
- Confirmar que la referencia aparece una vez; repetir acción no debe duplicarla.
- Abrir la imagen desde álbum y verificar que resuelve el mismo recurso visual.

### Regresión R21
- Ajustar imagen de Fight Card.
- Ajustar producto Showcase.
- Ajustar publicación Social propia.
- Ajustar Perfil/Comunidad según permisos.

## Android · APK Signed de prueba
1. Abrir `android` en Android Studio.
2. Esperar Gradle Sync.
3. Generate Signed App Bundle or APK -> APK -> release.
4. Usar el JKS release local de KOMBAX. No compartir contraseñas en texto.
5. Instalar APK en dispositivo real.
6. Repetir las pruebas de Events, Main/Co-Main, álbum, Social y Showcase.
7. Probar portrait/landscape y navegación atrás.

## Criterio de aceptación visual
No declarar validación visual hasta comprobarlo físicamente. Si existe flash, salto o demora reproducible, anotar pantalla, acción, conexión y si ocurre en primera carga o al volver atrás.
