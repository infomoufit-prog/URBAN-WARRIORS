import { backend } from '../core/backend.js';
import { openForm, toast } from '../ui/components.js';

export function openAuthenticatedPasswordChange({onComplete}={}){
  const modal=openForm({
    title:'Seguridad y acceso',
    subtitle:'Cambia la contraseña de tu cuenta KOMBAX. Por seguridad verificaremos primero tu contraseña actual y cerraremos esta sesión al terminar.',
    width:'620px',
    fields:[
      {name:'current_password',label:'Contraseña actual',type:'password',required:true,help:'Necesaria para confirmar que eres tú.'},
      {name:'new_password',label:'Nueva contraseña',type:'password',required:true,help:'Mínimo 8 caracteres. Usa una contraseña distinta de la actual.'},
      {name:'new_password_repeat',label:'Repite la nueva contraseña',type:'password',required:true}
    ],
    submitText:'Cambiar contraseña',
    onSubmit:async values=>{
      const current=String(values.current_password||'');
      const next=String(values.new_password||'');
      if(!current)throw new Error('Introduce tu contraseña actual.');
      if(next.length<8)throw new Error('La nueva contraseña debe tener al menos 8 caracteres.');
      if(current===next)throw new Error('La nueva contraseña debe ser distinta de la actual.');
      if(next!==values.new_password_repeat)throw new Error('Las dos contraseñas nuevas no coinciden.');
      await backend.changeOwnPassword({currentPassword:current,password:next});
      toast('Contraseña actualizada. Por seguridad, vuelve a iniciar sesión con la nueva contraseña.');
      setTimeout(()=>{if(onComplete)onComplete();else location.reload();},420);
    }
  });
  const current=modal.form.elements.current_password,newPassword=modal.form.elements.new_password,repeat=modal.form.elements.new_password_repeat;
  current?.setAttribute('autocomplete','current-password');
  newPassword?.setAttribute('autocomplete','new-password');
  repeat?.setAttribute('autocomplete','new-password');
  return modal;
}
