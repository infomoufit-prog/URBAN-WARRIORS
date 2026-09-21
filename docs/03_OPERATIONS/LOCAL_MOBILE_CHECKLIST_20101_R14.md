# CHECKLIST LOCAL + MÓVIL + APK · KOMBAX 20.101 R14

## 1. Prueba local
1. Extraer el ZIP en una carpeta nueva.
2. Abrir terminal en la raíz.
3. Ejecutar `npm install` si la carpeta no conserva dependencias instaladas.
4. Ejecutar `npm run dev`.
5. Abrir la URL local indicada por el servidor.

## 2. Validación de Crear evento
Con un club/federación que tenga permiso real `events.public.organize`:
1. Entrar en KOMBAX Events.
2. Pulsar `Crear evento`.
3. Guardar la ficha inicial.
4. Confirmar que se abre `Constructor del evento`.
5. Verificar las seis etapas:
   - Ficha e información
   - Portada y banner
   - Organización
   - Participantes y fotos
   - Fight Card y horarios
   - Álbum y multimedia

## 3. Participantes / fotos
1. Añadir participante externo.
2. Subir JPG/PNG/WEBP o indicar URL HTTPS.
3. Volver a Participantes.
4. Pulsar `Editar ficha / foto`.
5. Reemplazar la fotografía y guardar.
6. Confirmar que la Fight Card sigue funcionando aunque un participante no tenga foto.

## 4. Fight Card
1. Tener al menos dos participantes aceptados.
2. Abrir `Fight Card y horarios`.
3. Pulsar `Añadir combate`.
4. Seleccionar A/B.
5. Completar disciplina, categoría, peso, tatami/ring, orden y hora.
6. Guardar.
7. Editar el combate y cambiar horario/tatami.
8. Verificar la tarjeta pública.

## 5. Álbum
Como organizador:
1. Abrir el evento.
2. Confirmar que aparece `Álbum · 0` si está vacío.
3. Entrar en Álbum.
4. Pulsar `Subir fotos o vídeos`.
5. Subir varias fotos.
6. Subir un vídeo compatible.
7. Probar Previo / Evento / Posterior.
8. Probar `Permitir descarga`.
9. Opcional: asociar una subida a un combate.
10. Opcional: asociar a un Competidor KOMBAX.
11. Confirmar contador máximo 15 fotos / 5 vídeos almacenados.
12. Retirar una pieza y comprobar que libera plaza.

Como público:
- un álbum vacío no debe aparecer;
- al existir media visible, debe aparecer en navegación y detalle.

## 6. Eventos de control
Verificar:
- `Noche de Impacto · Barcelona`: 6 Fight Cards.
- `Urban Warriors · Interclub de Jiu-Jitsu · Palafolls`: 6 Fight Cards.

El álbum de ambos está actualmente vacío en Supabase hasta que se suba media real desde el gestor.

## 7. Android / APK Signed
Antes de firmar:
1. Restaurar localmente `android/keystore.properties` usando la plantilla/scripts incluidos.
2. No subir ni compartir ese fichero ni sus contraseñas.
3. Abrir `android/` en Android Studio.
4. Sincronizar Gradle.
5. Generar APK Signed con el JKS incluido/restaurado.
6. Instalar sobre el móvil de prueba.

## 8. QA móvil prioritario
- 360 px
- 390/412 px Android
- 430 px
- 620 px

Comprobar especialmente:
- constructor sin scroll horizontal;
- botones accesibles;
- selectores de Fight Card;
- selector de asociación multimedia;
- carga de archivos desde galería/cámara/selector Android;
- retorno correcto al constructor tras guardar.
