# Escenarios RLS obligatorios

1. Usuario Club A: no puede seleccionar socios, cuotas, grupos ni comunicaciones del Club B.
2. Dirección Club A: puede gestionar miembros, configuración, socios y tarifas del Club A.
3. Monitor Club A: puede consultar sus grupos y registrar asistencia; no puede validar pagos.
4. Tutor: solo puede consultar socios vinculados mediante `tutores_socios`.
5. Alumno adulto: puede consultar su propio `socios.perfil_id`; no puede modificar grado ni cuota.
6. `generar_cuotas_periodo`: crea una única cuota por socio/periodo/concepto aunque se ejecute dos veces.
7. Referencias cruzadas: no se puede asignar un grupo del Club B a un socio del Club A.
8. Dos clubes pueden tener una disciplina llamada `Muay Thai`.
