# QA LOCAL · KOMBAX build 20028

## Gate estático
- [x] npm test PASS
- [x] npm run build PASS
- [x] 70 archivos sincronizados: web = dist = Android
- [x] JS syntax PASS
- [x] applicationId conservado
- [x] versionCode 20028
- [x] smoke HTTP local 200
- [x] assets versionados `?v=20028`

## Gate Android local
- [x] proyecto Android presente
- [x] assets/www sincronizado
- [x] applicationId `com.urbanwarriors.app`
- [x] versionCode `20028`
- [ ] `google-services.json` real — externo, no incluido
- [ ] `android/keystore.properties` + JKS — externo, no incluido

## Gate Supabase remoto
- [x] 037–050 ya aplicadas/verificadas durante la sesión anterior
- [ ] 051
- [ ] 052
- [ ] 053
- [ ] 054
- [ ] 055
- [ ] asignar platform_admin por UUID
- [ ] 056
- [ ] tests transaccionales reales
- [ ] E2E por roles
- [ ] aislamiento dos clubes
- [ ] Storage real

## Gate funcional local posterior a Supabase 051–056
- [ ] Gestor actúa como Club
- [ ] Coordinación actúa como Club según permisos
- [ ] Miembro sigue siendo Miembro
- [ ] Competidor requiere identidad especializada
- [ ] logo/avatar/banner visibles
- [ ] perfil público completo clicable
- [ ] editar bio/avatar/portada de miembro
- [ ] publicar foto directa
- [ ] publicar vídeo <=15s
- [ ] elegir multimedia del álbum
- [ ] comentarios/guardados/reportes/bloqueos
- [ ] Showcase CTA/guardar/compartir
- [ ] Hub del Club
- [ ] Administración KOMBAX global
- [ ] no hay mensajes técnicos en recorrido normal
