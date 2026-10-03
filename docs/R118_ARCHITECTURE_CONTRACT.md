# KOMBAX R118 — Contrato de arquitectura

Estado: contrato canónico de implementación para estabilización del piloto.

## 1. Cuenta, identidad y Perfil Social

1. Un correo confirmado corresponde a una única cuenta Auth de KOMBAX.
2. La cuenta es gratuita por defecto y no representa por sí misma un plan comercial.
3. Cada persona dispone como máximo de un Perfil Social público canónico.
4. `public.identidades_sociales` se considera la identidad social canónica de persona aunque el valor legado de `tipo` siga siendo `miembro` por compatibilidad.
5. Los perfiles especializados personales son facetas de la misma persona; no crean otra cuenta ni otra identidad social canónica.
6. Organizaciones (Club, Federación, Marca) conservan perfiles públicos independientes de las personas que las gestionan.

## 2. Multiperfil personal

Una misma cuenta puede acumular facetas compatibles, entre otras:
- Miembro / Practicante.
- Competidor.
- Profesional.
- Especialidades profesionales: Entrenador, Representante/Manager, Médico/Sanitario, Árbitro/Juez, Promotor/Organizador.

Reglas:
- Una cuenta puede tener Competidor y Profesional simultáneamente.
- Una cuenta puede dirigir/coordinador un Club y además tener Competidor/Profesional.
- Un rol privado de Club no crea un perfil profesional público.
- Una especialidad profesional verificada no otorga permisos internos de Club.
- Se mantiene como máximo una faceta por tipo personal cuando ya existe una restricción de unicidad por cuenta.
- `kombax_account_types_r100` pasa a ser metadato legado/preferencia de onboarding y no una autoridad de permisos o exclusividad.

## 3. Roles organizativos

Los roles `direccion`, `coordinacion`, `secretaria`, `economia`, `comunicacion`, `monitor`, `alumno`, `familia` describen permisos privados dentro de un Club.
No sustituyen ni bloquean perfiles personales especializados.

## 4. Verificación profesional

Una faceta profesional puede declarar una o varias credenciales.
Cada credencial:
- pertenece a un perfil Profesional;
- referencia una especialidad admitida;
- puede incluir organismo emisor, referencia pública, URL de verificación, vigencia y evidencia documental privada;
- mantiene estado `declarada | pendiente | verificada | rechazada | expirada`;
- registra aceptación versionada de declaración de autenticidad;
- es privada por defecto y solo expone públicamente los campos autorizados por el profesional;
- nunca expone la ruta del documento privado en APIs públicas.

El badge debe describir lo efectivamente verificado; no implica que todas las afirmaciones del perfil estén certificadas.

## 5. Descubrimiento sin duplicados

1. Los filtros pueden encontrar una persona por cualquiera de sus facetas.
2. Una búsqueda general no debe renderizar dos tarjetas para la misma cuenta.
3. El resultado canónico se agrupa por propietario `perfil_id`.
4. Se muestran facetas coincidentes como atributos/badges de una única persona.
5. "Ver perfil" resuelve al Perfil Social canónico cuando existe.
6. Los endpoints especializados se conservan para compatibilidad operativa.

## 6. Suscripción, activaciones y entitlements

Separación obligatoria:
- Cuenta Auth.
- Perfil personal/faceta.
- Organización.
- Rol privado.
- Entitlement/suscripción/activación.

Nunca se debe inferir "usuario Premium" global.
Los derechos se resuelven por `subject_type + subject_id + capability`.

Ejemplos:
- Cuenta gratuita + Competidor gratuito + Club Premium.
- Cuenta gratuita + Profesional verificado + activación puntual de una capacidad.
- Beneficio piloto de Club con fuente `pilot`, sin convertir los perfiles personales del gestor en Premium.

## 7. Clubes piloto

Durante la ventana piloto:
- máximo configurado: 4 Clubes;
- email confirmado + perfil de cuenta + nombre del Club + declaración son suficientes para alta inicial;
- teléfono, ubicación, disciplinas y documentación son progresivos;
- una cuenta puede crear/gestionar un Club aunque su `account_type` legado sea Miembro, Competidor o Profesional;
- al crear el Club se asigna Dirección, códigos y beneficio piloto;
- no se crean datos ficticios para QA de producción.

## 8. Incorporación al Club

Deben coexistir:

### Alumnos/familias
A. Código general de alumnos/familias.
B. Invitación nominativa por email con código personal.

### Equipo
A. Código general de equipo -> solicitud pendiente -> revisión -> rol aprobado/rechazado.
B. Invitación nominativa por email con rol previamente autorizado -> aceptación por el mismo correo.

La invitación debe registrar creación, estado de email, aceptación, caducidad o revocación.

## 9. Notificaciones accionables

Una tarea se mantiene accionable mientras la entidad subyacente siga pendiente.
Leer o abrir la notificación no resuelve la tarea.
Al aprobar/rechazar/validar, la notificación operativa se archiva y, cuando corresponda, se informa al solicitante.

## 10. Compatibilidad y seguridad

- No duplicar Auth, perfiles sociales, fichas de alumno ni membresías.
- No auto-merge sin evidencia suficiente.
- No otorgar capacidades administrativas por crear un perfil especializado.
- No cambiar de Club silenciosamente.
- No exponer documentación privada.
- Mantener RLS y SECURITY DEFINER con comprobaciones explícitas.
- Las migraciones R118 serán aditivas o `CREATE OR REPLACE` y tendrán archivo de rollback cuando modifiquen contratos existentes.

## 11. Gate de release

No se mueve `main` hasta superar:
- auditoría de esquema y funciones;
- pruebas de identidad multiperfil;
- alta Club piloto;
- códigos e invitaciones;
- notificaciones;
- verificación profesional;
- descubrimiento agrupado;
- regresiones R115–R117;
- paridad web/dist/Android;
- versionado Android;
- auditoría Supabase de seguridad y rendimiento.
