import fs from 'node:fs';
import path from 'node:path';

const root=process.cwd();
const dir=path.join(root,'supabase','auth_templates');
const required={
  'confirmation_20072.html':'{{ .ConfirmationURL }}',
  'recovery_otp_20072.html':'{{ .Token }}',
  'magic_link_otp_20072.html':'{{ .Token }}',
  'invite_20072.html':'{{ .ConfirmationURL }}',
  'reauthentication_otp_20072.html':'{{ .Token }}',
  'password_changed_20072.html':null,
  'README_20072.md':null
};
for(const [file,token] of Object.entries(required)){
  const p=path.join(dir,file);
  if(!fs.existsSync(p))throw new Error(`Falta plantilla Auth 20072: ${file}`);
  const text=fs.readFileSync(p,'utf8');
  if(!/KOMBAX/.test(text))throw new Error(`${file}: falta branding KOMBAX`);
  if(token&&!text.includes(token))throw new Error(`${file}: falta variable ${token}`);
  if(/SUPABASE_SERVICE_ROLE_KEY|service[_ -]?role\s*[:=]|smtp[_ -]?password\s*[:=]|BEGIN (?:RSA |EC )?PRIVATE KEY/i.test(text))throw new Error(`${file}: posible secreto incrustado`);
  if(/<img\b[^>]*https?:\/\//i.test(text))throw new Error(`${file}: no se permiten imágenes remotas`);
}
const recovery=fs.readFileSync(path.join(dir,'recovery_otp_20072.html'),'utf8');
const magic=fs.readFileSync(path.join(dir,'magic_link_otp_20072.html'),'utf8');
if(recovery.includes('{{ .ConfirmationURL }}'))throw new Error('Recovery 20072 debe ser OTP, no link-only.');
if(magic.includes('{{ .ConfirmationURL }}'))throw new Error('Magic Link 20072 se usa como OTP Owner y no debe reemplazar el código por un enlace.');
const docs=fs.readFileSync(path.join(dir,'README_20072.md'),'utf8');
for(const needle of ['create_user:false','type: recovery','https://kombax.es','Magic Link']){
  if(!docs.includes(needle))throw new Error(`README Auth 20072 incompleto: ${needle}`);
}
console.log('KOMBAX 20072 auth email templates: PASS');
