# KOMBAX 20.101 R19 · Validation Checklist

## PWA / navegador / PC
1. Ejecutar la build local o desplegar la carpeta `dist` por el flujo habitual.
2. Entrar en KOMBAX Showcase.
3. Localizar Urban Warriors como vendedor.
4. Comprobar los tres productos:
   - Casco Integral Urban Warriors Pro · 79,90 €.
   - Guantes Integrales Urban Warriors Elite · 64,90 €.
   - Whey Protein Recovery Blend Urban Performance · 49,90 €.
5. Confirmar que cada uno tiene una imagen distinta y que no aparece el icono de imagen rota.
6. Abrir la ficha completa y revisar categoría, descripción y precio orientativo.
7. Pulsar `Me interesa` y comprobar que abre/crea la conversación Showcase asociada a ESE producto.
8. Volver al listado y verificar que no se ha mezclado el hilo con otro producto.

## Responsive
Validar Showcase en:
- móvil vertical
- móvil horizontal
- tablet vertical
- tablet horizontal
- escritorio/PWA

## Android
1. Restaurar `android/keystore.properties` localmente usando el helper/documentación ya incluida.
2. Ejecutar `npm run android:preflight` y exigir 5/5 antes de firmar.
3. Generar APK Signed desde Android Studio con el JKS release existente.
4. Instalar la APK sobre dispositivo de prueba.
5. Repetir las 8 comprobaciones de Showcase anteriores.
6. Verificar además navegación atrás, apertura de ficha y conversación por producto.

## Aceptación
No marcar R19 como aprobada visualmente hasta que las tres imágenes y las tres fichas se hayan comprobado al menos en PWA/PC y en una APK construida desde R19.
