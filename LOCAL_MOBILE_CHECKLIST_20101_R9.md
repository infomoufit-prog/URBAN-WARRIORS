# Checklist local + móvil · KOMBAX 20.101 R9

## Local
- [ ] Ejecutar `npm run dev`.
- [ ] Hacer recarga forzada del navegador (Ctrl+F5).
- [ ] Confirmar imagen multi-peleadores en la entrada.
- [ ] Esperar 10–20 s y confirmar desplazamiento del humo rojo y azul.
- [ ] Entrar en KOMBAX Social y comprobar peleador ampliado, centrado y sin cortar rostro/manos de forma agresiva.
- [ ] Entrar en KOMBAX Events > Noche de Impacto Barcelona.
- [ ] Confirmar que Main Event queda más compacto a la izquierda.
- [ ] Confirmar que Club Fénix / Élite / Nova Combat caben en la esquina inferior derecha sin solaparse.
- [ ] Confirmar que botones, scroll y navegación siguen respondiendo.

## APK Signed
- [ ] Restaurar `android/keystore.properties` mediante `LOCAL_RELEASE_SIGNING/RESTORE_SIGNING_WINDOWS.cmd` o `.ps1`.
- [ ] Generar APK Signed desde Android Studio con la JKS habitual.
- [ ] Instalar R9.
- [ ] Repetir la entrada: imagen + humo.
- [ ] Probar Social en vertical.
- [ ] Abrir Noche de Impacto y revisar organizadores/Main Event.
- [ ] Abrir Urban Warriors Interclub Jiu-Jitsu y continuar su instalación/QA después de validar estas correcciones visuales.

## Nota de accesibilidad
Si el sistema operativo tiene activada la preferencia “reducir movimiento”, las animaciones se detienen por diseño. Las capas visuales permanecen presentes.
