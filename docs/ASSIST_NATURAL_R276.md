# R276: lenguaje natural y utilidad de Assist

Backend actualizado en Supabase: kombax-assist-r38, versión 26 ACTIVE, JWT obligatorio. Lectura posterior: cinco archivos idénticos al código preparado. Solo cambia un bloque de instrucciones de gestión y su selección; comparación con R275 entregado y versión remota anterior confirma que el código operativo permanece igual.

Assist explica su utilidad al preguntarle qué es o qué puede hacer: interpretar los datos disponibles del espacio activo y ayudar a priorizar pendientes. Ejemplos adaptados a Club, Marca y Federación. Distingue Ayuda (uso de plataforma), Assist (gestión) y Migrations (preparar incorporación de datos). No promete acceso a toda la base de datos ni acciones que no ejecuta.

Lenguaje: intención antes de procedimiento, definiciones sencillas, respuesta directa a cifras respaldadas, seguimiento del contexto reciente, errores de escritura sencillos, una aclaración cuando sea imprescindible, sin presentaciones ni preguntas de cierre repetidas. Un contexto ausente o parcial no significa saldo cero. No se amplían permisos ni se eliminan confirmaciones.

Sin cambios de frontend, base de datos, modelo, límites, saldo compartido ni secrets. No necesita desplegar Netlify. Afecta a las siguientes respuestas de Assist, no reescribe mensajes anteriores. No se modifican Migrations, Soporte ni Ayuda R275.

Pruebas locales con proveedor simulado: R276 91 comprobaciones; Assist/Migrations 38; handler Ayuda 34; invitaciones 16 sin emails enviados; Ayuda natural 18; Ayuda universal 27. Todas correctas. Son suites con cobertura compartida, no una cifra de casos únicos. La regresión completa de release R275 fue 125 comandos PASS y 3 P2 conocidos; no se repitió completa por este cambio exclusivo de instrucciones. No se ejecutó una inferencia real: falta valorar el texto que genere el modelo en una consulta real del usuario. No se presenta una prueba de contrato como evaluación de calidad lingüística del modelo.

No se hizo commit, push, PR, merge ni deploy Netlify. No se generó otro ZIP por este ajuste. El ZIP R275 entregado se conserva intacto y contiene la versión de backend anterior; para volver a desplegar funciones en el futuro debe usarse el código local actualizado con R276, no restaurar la función desde R275. El despliegue normal del frontend R275 no redespliega esta Edge Function.

Código actualizado: work/r275-natural-help/supabase/functions/kombax-assist-r38/index.ts. Prueba añadida: scripts/test-assist-natural-r276.mjs.

Referencia de instrucciones y ejemplos: https://developers.openai.com/api/docs/guides/prompt-engineering . Despliegue de funciones: https://supabase.com/docs/guides/functions/deploy . No se ha reentrenado el modelo.

## Evidencia de lectura posterior

```json
{
  "name": "kombax-assist-r38",
  "version": 26,
  "status": "ACTIVE",
  "verify_jwt": true,
  "files": [
    {
      "file": "kombax-assist-r38/index.ts",
      "identical": true
    },
    {
      "file": "_shared/usage-help-guide.ts",
      "identical": true
    },
    {
      "file": "_shared/usage-help-catalog.json",
      "identical": true
    },
    {
      "file": "_shared/usage-help-knowledge.js",
      "identical": true
    },
    {
      "file": "kombax-assist-r38/deno.json",
      "identical": true
    }
  ]
}
```

