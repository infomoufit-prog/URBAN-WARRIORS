import {createHash} from 'node:crypto';
// Git can change CRLF to LF at checkout. Preserve all other source bytes,
// including whitespace and final newlines; meaningful edits must still fail.
export function sourceFingerprint(bytes){return createHash('sha256').update(Buffer.from(bytes).toString('utf8').replace(/\r\n/g,'\n'),'utf8').digest('hex');}
