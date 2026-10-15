# R273 · Conversación de ayuda

Fuente: copia nueva extraída del acumulativo R272. R272 y sus partes entregadas se conservan intactos.

## Implementado

- Enter envía; Mayús+Enter inserta otra línea; se respeta la composición de texto (IME).
- La pregunta se añade inmediatamente, se vacía el campo y aparece Preparando respuesta… mientras se obtiene la respuesta. El estado se retira al finalizar o fallar.
- Todas las instrucciones de una guía se muestran en una sola respuesta, sin el recorte anterior de cinco pasos. Los detalles adicionales y hasta tres tareas relacionadas se pliegan en esa respuesta.
- Ejemplos iniciales se ocultan al enviar. La información de cupo permanece en Uso de la ayuda. No se repiten seis botones y otra respuesta adicional por cada consulta.
- Modo Guiarme paso a paso con anterior/siguiente, contador y regreso a la guía completa. Es una guía de lectura: no rellena formularios ni ejecuta acciones, ni afirma haber comprobado que el usuario terminó un paso.
- Recuperación conservadora de errores de escritura e intercambio de letras; una coincidencia ambigua no se corrige arbitrariamente. Respeta el contexto y el filtro de fuentes.
- Saludos y agradecimientos se responden localmente. Sin guía, una identidad elegible con derecho/cupo/saldo comprobados puede recurrir a la API existente. Las demás reciben una aclaración orientativa sin llamada al modelo.
- Si fallan las guías o la API, se conserva la consulta y se da una explicación con alternativas. No se garantiza disponibilidad del proveedor ni una respuesta factual a cualquier tema.
- Conversación conservada durante navegación dentro de la identidad y al cerrar/reabrir, como en R272. La recarga completa sigue reiniciando el transcript visible.

## Comprobación

Pruebas nuevas: recuperación de cuoats, sesoin y fotto; conservación de intención exacta, entrada sin sentido, alcance de documentación pública, longitud y cortesía sin IA. Continúan las 46 pruebas de contexto y las 32 del handler con proveedor simulado.

Navegador con componentes reales y datos simulados: Enter, salto de línea, recuperación de sesoin, guía completa, tutorial en paso 2, indicador durante consulta IA, respuesta simulada, fallo simulado de API y orientación inicial sin incrementar el contador de consultas IA. No se hicieron inferencias reales ni se gastaron créditos en estas pruebas.

No se desplegó R273 en Netlify, GitHub ni Supabase durante esta intervención. La UI utiliza el backend R272 v21 ya desplegado y su gate comercial; no añade cuotas ni saldos. El matcher compartido actualizado está incluido en el código acumulativo local, pero no se ha desplegado su copia de servidor. La corrección de erratas local ya funciona sin ese despliegue.

La propuesta de la barra lateral está en PROPUESTA_MENU_CLUB_R273.md. No se ha aplicado: se conserva la agrupación R272 hasta revisar esa propuesta.

La ayuda se apoya en las 67 guías existentes; no es un reentrenamiento del modelo ni se afirma cobertura perfecta de todos los procedimientos de KOMBAX. La calidad de una generación real y su latencia requieren una consulta real autorizada. La fuente de guías sigue siendo español y conserva las limitaciones de traducción de R272.

Resultado final de regresión: 122 PASS, 3 P2 de traducción heredados y 0 fallos nuevos. Compatibilidad Linux: 395 JS y 964 importaciones; 663 recursos iguales en web/dist/Android. Registro en R273_RELEASE_BUILD.log.

## Ajuste posterior: ayuda universal y lenguaje sencillo

La instrucción más reciente sustituye la visibilidad restringida de R272: el acceso de ayuda aparece en todas las pantallas y para todas las cuentas. Los perfiles sin derecho a IA usan documentación local; no llaman al proveedor ni consultan el presupuesto administrativo. El acceso que amplía una respuesta solo aparece tras comprobar derecho, cupo y saldo.

Se retiran del chat el bloque Uso de la ayuda y las explicaciones de tokens/cupos/créditos. La acción se llama Necesito más ayuda y los errores se expresan con lenguaje común. Las comprobaciones económicas y de seguridad siguen en el código y en el backend. Las sugerencias iniciales se adaptan a alumno, competidor, profesional, espectador y organización.

Verificación de este ajuste: 46 pruebas de contexto/visibilidad, 9 de comprensión y 32 del handler simulado, más build de 663 recursos iguales en web/dist/Android. Navegador con alumno y competidor: acceso visible, guías correspondientes, sin botón de ampliación ni consultas IA. La pasada acumulativa de 122 PASS / 3 P2 se realizó antes de este último ajuste; para este ajuste se ejecutaron las pruebas específicas y el build, no otra pasada completa.
