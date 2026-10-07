export function bindAccountModeFields(form,modeName='modo'){
 const mode=form.elements[modeName];if(!mode)return;
 const sync=()=>{
  const creating=mode.value==='nueva';
  for(const name of ['nombre','apellidos','fecha_nacimiento']){
   const input=form.elements[name];if(!input)continue;
   const field=input.closest('.field');if(field)field.hidden=!creating;
   input.disabled=!creating;input.required=creating;
  }
  const password=form.elements.password;if(password)password.minLength=creating?8:0;
 };
 mode.addEventListener('change',sync);sync();
}
