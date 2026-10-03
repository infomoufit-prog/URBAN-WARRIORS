import {readFileSync} from 'node:fs';
import {SourceTextModule} from 'node:vm';
const files=JSON.parse(readFileSync(0,'utf8'));
if(!Array.isArray(files)||!files.length)throw new Error('No module files supplied');
for(const file of files){
 try{new SourceTextModule(readFileSync(file,'utf8'),{identifier:file});}
 catch(error){throw new Error(`${file}: ${error.message}`,{cause:error});}
}
console.log(files.length);
