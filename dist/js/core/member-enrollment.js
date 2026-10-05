// Enrollment is additive: the same member may join multiple disciplines/groups.
export function availableEnrollmentGroups(groups=[],disciplineId,enrollments=[],memberId){
 const active=new Set(enrollments.filter(e=>e.socio_id===memberId&&e.activa).map(e=>e.grupo_id));
 return groups.filter(g=>g.activo&&g.disciplina_id===disciplineId&&!active.has(g.id));
}
export function validateEnrollmentSelection({memberId,disciplineId,groupId,groups=[],enrollments=[]}){
 const group=groups.find(g=>g.id===groupId&&g.activo);
 if(!group||group.disciplina_id!==disciplineId)throw new Error('Selecciona un grupo activo de la disciplina elegida.');
 if(enrollments.some(e=>e.socio_id===memberId&&e.grupo_id===groupId&&e.activa))throw new Error('El alumno ya tiene una matrícula activa en ese grupo.');
 return {socio_id:memberId,disciplina_id:disciplineId,grupo_id:groupId};
}
export function bindEnrollmentGroups(form,{groups=[],enrollments=[],memberId}={}){
 const discipline=form.elements.disciplina_id,group=form.elements.grupo_id;
 if(!discipline||!group)return;
 const refresh=()=>{
  const previous=group.value,rows=availableEnrollmentGroups(groups,discipline.value,enrollments,memberId);
  group.replaceChildren(new Option(discipline.value?(rows.length?'Selecciona un grupo':'Sin grupos disponibles'):'Selecciona primero una disciplina',''));
  rows.forEach(row=>group.add(new Option(row.nombre,row.id)));
  group.disabled=!discipline.value||!rows.length;
  if(rows.some(row=>row.id===previous))group.value=previous;
 };
 discipline.addEventListener('change',refresh);refresh();
}
