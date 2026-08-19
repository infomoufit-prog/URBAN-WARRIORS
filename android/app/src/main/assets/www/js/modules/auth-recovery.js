import { backend } from '../core/backend.js';
import { openForm, toast } from '../ui/components.js';

const normalizeEmail=value=>String(value||'').trim().toLowerCase();
const neutralMessage='Si existe una cuenta con ese correo, recibirás un código de 6 dígitos para cambiar la contraseña.';

function openCodeStep({email,onComplete}){
  const modal=openForm({
    title:'Verificar código',
    subtitle:`Hemos procesado la solicitud para ${email}. Introduce el código recibido y elige una nueva contraseña.`,
    width:'620px',
    fields:[
      {name:'token',label:'Código de verificación',required:true,maxLength:6,placeholder:'000000',help:'Código de 6 dígitos enviado por correo.'},
      {name:'password',label:'Nueva contraseña',type:'password',required:true,help:'Mínimo 8 caracteres.'},
      {name:'password_repeat',label:'Repite la nueva contraseña',type:'password',required:true}
    ],
    submitText:'Cambiar contraseña',
    onSubmit:async values=>{
      const token=String(values.token||'').replace(/\s+/g,'');
      if(!/^\d{6}$/.test(token))throw new Error('El código debe tener 6 dígitos.');
      if(String(values.password||'').length<8)throw new Error('La nueva contraseña debe tener al menos 8 caracteres.');
      if(values.password!==values.password_repeat)throw new Error('Las dos contraseñas no coinciden.');
      await backend.completePasswordRecovery({email,token,password:values.password});
      toast('Contraseña actualizada. Ya puedes entrar con la nueva contraseña.');
      setTimeout(()=>onComplete?.(email),340);
    }
  });
  const actions=modal.form.querySelector('.modal-actions');
  const resend=document.createElement('button');
  resend.type='button';resend.className='btn btn-ghost';resend.textContent='Reenviar código';
  resend.addEventListener('click',async()=>{
    resend.disabled=true;
    try{await backend.requestPasswordRecovery(email);toast(neutralMessage);}
    catch(error){toast(error.message||'No se pudo solicitar otro código.','error');}
    finally{setTimeout(()=>{if(resend.isConnected)resend.disabled=false;},60000);}
  });
  actions?.prepend(resend);
}

export function openPasswordRecovery({prefillEmail='',onComplete}={}){
  openForm({
    title:'He olvidado mi contraseña',
    subtitle:'Te enviaremos un código de verificación al correo de tu cuenta. No crearemos ninguna cuenta nueva.',
    width:'600px',
    fields:[{name:'email',label:'Correo electrónico',type:'email',required:true,value:normalizeEmail(prefillEmail)}],
    submitText:'Enviar código',
    onSubmit:async values=>{
      const email=normalizeEmail(values.email);
      await backend.requestPasswordRecovery(email);
      toast(neutralMessage);
      setTimeout(()=>openCodeStep({email,onComplete}),340);
    }
  });
}
