import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const root=process.cwd();
const dir=path.join(root,'supabase','auth_templates');
const required={
  'confirmation_20073.html':'{{ .ConfirmationURL }}',
  'recovery_otp_20073.html':'{{ .Token }}',
  'magic_link_otp_20073.html':'{{ .Token }}',
  'invite_20073.html':'{{ .ConfirmationURL }}',
  'reauthentication_otp_20073.html':'{{ .Token }}',
  'password_changed_20073.html':null,
  'README_20073.md':null
};
for(const [file,token] of Object.entries(required)){
  const p=path.join(dir,file);
  assert.ok(fs.existsSync(p),`Falta plantilla Auth 20073: ${file}`);
  const text=fs.readFileSync(p,'utf8');
  assert.match(text,/KOMBAX/,`${file}: falta branding KOMBAX`);
  if(token)assert.ok(text.includes(token),`${file}: falta variable ${token}`);
  assert.doesNotMatch(text,/SUPABASE_SERVICE_ROLE_KEY|service[_ -]?role\s*[:=]|smtp[_ -]?password\s*[:=]|BEGIN (?:RSA |EC )?PRIVATE KEY/i,`${file}: posible secreto incrustado`);
  assert.doesNotMatch(text,/<img\b[^>]*https?:\/\//i,`${file}: no se permiten imágenes remotas`);
  if(file.endsWith('.html')){
    assert.match(text,/display:none;max-height:0/,`${file}: falta preheader`);
    assert.match(text,/Seguridad de cuenta/,`${file}: falta pie de seguridad`);
    assert.match(text,/role="presentation"/,`${file}: layout de email no robusto`);
  }
}
const confirmation=fs.readFileSync(path.join(dir,'confirmation_20073.html'),'utf8');
const recovery=fs.readFileSync(path.join(dir,'recovery_otp_20073.html'),'utf8');
const magic=fs.readFileSync(path.join(dir,'magic_link_otp_20073.html'),'utf8');
const invite=fs.readFileSync(path.join(dir,'invite_20073.html'),'utf8');
const reauth=fs.readFileSync(path.join(dir,'reauthentication_otp_20073.html'),'utf8');
const changed=fs.readFileSync(path.join(dir,'password_changed_20073.html'),'utf8');
assert.match(confirmation,/Tu cuenta está a un paso/);
assert.match(recovery,/Tu contraseña no cambiará hasta que completes el proceso/);
assert.match(recovery,/nunca te pedirá que lo compartas/i);
assert.match(magic,/Verifica tu acceso a KOMBAX/);
assert.match(invite,/comprueba que reconoces la invitación/i);
assert.match(reauth,/Confirma que eres tú/);
assert.match(changed,/Si has realizado tú el cambio, no necesitas hacer nada más/);
assert.ok(!recovery.includes('{{ .ConfirmationURL }}'),'Recovery 20073 debe ser OTP, no link-only.');
assert.ok(!magic.includes('{{ .ConfirmationURL }}'),'Magic Link 20073 se usa como OTP Owner y no debe convertirse en link-only.');
const docs=fs.readFileSync(path.join(dir,'README_20073.md'),'utf8');
for(const needle of ['create_user:false','type: recovery','https://kombax.es','Activa tu cuenta KOMBAX','Confirma que eres tú · KOMBAX'])assert.ok(docs.includes(needle),`README Auth 20073 incompleto: ${needle}`);
console.log('KOMBAX 20073 premium auth email templates: PASS');
