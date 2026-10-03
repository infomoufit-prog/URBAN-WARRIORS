import { backend } from '../core/backend.js';
import { state } from '../core/state.js';
import { validateBirthDate } from '../core/account-birth-date.js';
import { openForm, toast } from '../ui/components.js';

let promptOpen=false;

export async function promptMissingAccountBirthDate({onSaved=null}={}){
  if(promptOpen||document.getElementById('modal-layer'))return false;
  const status=await backend.accountBirthDateStatus().catch(()=>null);
  if(!status||status.present===true){
    if(status?.present===true&&state.session)state.session={...state.session,birth_date_required:false,birth_date_age:status.age??null};
    return false;
  }
  promptOpen=true;
  const modal=openForm({
    title:'Completa tu cuenta KOMBAX',
    subtitle:'Necesitamos tu fecha de nacimiento para aplicar de forma privada las reglas de edad. No se muestra en tu perfil público.',
    width:'620px',
    fields:[{name:'fecha_nacimiento',label:'Fecha de nacimiento',type:'date',required:true,full:true,help:'Dato privado. Se utiliza únicamente para comprobar requisitos de edad y seguridad.'}],
    submitText:'Guardar y continuar',
    onSubmit:async v=>{
      const {value}=validateBirthDate(v.fecha_nacimiento);
      const result=await backend.setAccountBirthDate(value);
      toast('Fecha de nacimiento guardada de forma privada.');
      onSaved?.(result);
    }
  });
  const release=()=>{promptOpen=false;};
  modal.wrap.addEventListener('kx:modal-before-close',release,{once:true});
  return true;
}
