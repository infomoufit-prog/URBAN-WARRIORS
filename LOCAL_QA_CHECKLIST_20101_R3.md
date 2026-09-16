# Checklist local · KOMBAX 20.101 R3

Usar exactamente la carpeta/ZIP 20.101 R3. No mezclar con 20.101 anterior.

## 1 · Heroes Social / Events / Showcase
1. Arrancar KOMBAX en local.
2. Entrar en **KOMBAX Social**.
   - Debe verse claramente el peleador de fondo.
   - `TU RED. TU LEGADO.` debe conservar contraste y halo.
3. Entrar en **KOMBAX Events**.
   - Deben verse las dos luchadoras del hero.
   - Debe mantenerse `FROM HYPE TO HISTORY` y el slogan aprobado.
4. Entrar en **KOMBAX Showcase**.
   - Debe verse el atleta/fondo de Showcase.
5. Cambiar el ancho de la ventana o probar móvil.
   - La fotografía no debe desaparecer.
   - El texto debe seguir legible.
   - No debe haber parpadeos ni capas negras que tapen al protagonista.

**PASS**: las tres capas muestran protagonista + copy + logo oficial y mantienen rendimiento fluido.

## 2 · Noche de Impacto / Main Event
1. Abrir KOMBAX Events.
2. Localizar **Noche de Impacto · Barcelona**.
3. Confirmar en tarjeta/portada:
   - no aparece `DEMO QA` ni `· DEMO` en nombre público, organizador o aval;
   - aparece `Club Fénix Elite` como Organiza;
   - aparece `Federación Nova Combat` como Avala;
   - el Combate Estelar muestra fotos y nombres de Hugo “Raven” Salvatierra y Darío “Atlas” Moreno.
4. Entrar en el evento.
5. Ir a **Main Event**.
   - no debe existir el bloque negro vacío;
   - deben verse ambos peleadores, VS central y metadatos de combate.
6. Revisar Fight Card.
   - deben seguir existiendo los 6 combates;
   - el Main Event debe ser uno de esos mismos combates, no una copia paralela.

**PASS**: cartelera, detalle y Fight Card representan el mismo Main Event.

## 3 · Editor de evento
1. Con sesión Gestor/Owner y permisos del evento, abrir **Editar ficha** o **Portada / encuadre**.
2. Probar cartel:
   - seleccionar JPG/PNG/WEBP;
   - arrastrar el encuadre;
   - guardar.
3. Repetir para banner.
4. Cerrar y volver a abrir el editor.
   - el encuadre debe mantenerse.
5. En Fight Card, editar otro combate y marcar **Main Event / destacado**.
   - al guardar, solo ese combate debe quedar como Main Event.
6. En inscripción/participante externo, probar fotografía desde archivo.

**PASS**: un organizador real puede reproducir la presentación del evento ejemplo sin tocar código.

## 4 · Persistencia + Social + deep-link
1. Refrescar el navegador completamente.
2. Volver al evento.
   - encuadre, organización y Main Event deben persistir desde Supabase.
3. Compartir/abrir una referencia de combate en KOMBAX Social.
   - si ambos peleadores tienen fotografía, deben verse las dos imágenes con VS.
4. Probar deep-link:
   - `?event=noche-de-impacto-barcelona-demo`
   - y, si se usa una pelea concreta, `&fight=<uuid>`.
5. Confirmar que abre el mismo evento/fight normal, no una pantalla demo paralela.

**PASS**: datos persistentes, tarjeta Social enriquecida y rutas públicas normales.

## Cierre
Si los cuatro puntos son PASS, la 20.101 R3 puede pasar a deploy controlado de Netlify y posteriormente a APK signed/AAB desde esta misma fuente.
