import {esc} from '../core/utils.js';

// Existing links stay checked and cannot be removed here. Deactivation has its own explicit action.
export function mountMemberEnrollmentPicker(form,{disciplines=[],groups=[],enrollments=[],memberId,allowWithoutGroup=false}={}){
 const fieldset=document.createElement('fieldset');fieldset.className='kx-member-enrollment-picker';
 fieldset.innerHTML=`<legend>Disciplinas y grupos del alumno</legend><p>Marca todas las opciones que quieras añadir. Las matrículas actuales se conservan. Puedes elegir mañana y tarde y varias disciplinas.</p>${disciplines.filter(d=>d.activa).map(d=>{
  const rows=groups.filter(g=>g.activo&&g.disciplina_id===d.id);
  const choices=[...(allowWithoutGroup?[{id:'',nombre:'Disciplina sin grupo asignado'}]:[]),...rows];
  return `<details open><summary>${esc(d.nombre)}</summary>${choices.map(g=>{const active=enrollments.some(e=>e.socio_id===memberId&&e.disciplina_id===d.id&&(e.grupo_id||'')===g.id&&e.activa);return `<label class="kx-enrollment-choice"><input type="checkbox" data-enrollment-choice data-discipline="${esc(d.id)}" data-group="${esc(g.id)}" ${active?'checked disabled':''}><span>${esc(g.nombre)}${active?' · matrícula activa':''}</span></label>`;}).join('')||'<small>No hay grupos activos de esta disciplina.</small>'}</details>`;
 }).join('')||'<p>No hay disciplinas activas configuradas en este club.</p>'}`;
 const actions=form.querySelector('.form-actions,.modal-actions');if(actions)actions.before(fieldset);else form.append(fieldset);
 return ()=>[...fieldset.querySelectorAll('[data-enrollment-choice]:checked:not(:disabled)')].map(x=>({disciplina_id:x.dataset.discipline,grupo_id:x.dataset.group||null}));
}
