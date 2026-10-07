import assert from 'node:assert/strict';
import {PGlite} from '@electric-sql/pglite';
import {readFileSync} from 'node:fs';
import {clubSessionRole} from '../web/js/core/club-session-role.js';
const owner={rol:'direccion',coordinacion:true},secretary={rol:'secretaria',coordinacion:true};
const results=[
 [[owner],owner,'direccion'],
 [[secretary,owner],secretary,'direccion'],
 [[secretary,{rol:'economia',coordinacion:true}],secretary,'coordinacion'],
 [[{rol:'monitor'}],{rol:'monitor'},'monitor'],
 [[{rol:'secretaria'}],{rol:'secretaria'},'secretaria'],
 [[{rol:'direccion',activo:false},secretary],secretary,'coordinacion']
];
for(const [rows,candidate,expected] of results)assert.equal(clubSessionRole(rows,candidate).rol,expected);
assert.equal(clubSessionRole([secretary,owner],secretary).chosen,owner);
assert.equal(clubSessionRole([owner],owner).coordinacion,false);
const db=new PGlite();try{
await db.exec('create role anon;create role authenticated;create table miembros_club(id int primary key,rol text,coordinacion boolean);insert into miembros_club values(1,\'direccion\',true),(2,\'secretaria\',true),(3,\'monitor\',false);');
await db.exec(readFileSync('supabase/migrations/20261006200115_club_owner_session_priority_fix16.sql','utf8'));
assert.deepEqual((await db.query('select id,coordinacion from miembros_club order by id')).rows,[{id:1,coordinacion:false},{id:2,coordinacion:true},{id:3,coordinacion:false}]);
await db.exec("update miembros_club set coordinacion=true where id=1;insert into miembros_club values(4,'direccion',true);");
assert.equal((await db.query("select count(*)::int as n from miembros_club where rol='direccion' and coordinacion")).rows[0].n,0);
assert.equal((await db.query('select coordinacion from miembros_club where id=2')).rows[0].coordinacion,true);
console.log('PASS 11 club owner session / normalization checks');
}finally{await db.close();}
