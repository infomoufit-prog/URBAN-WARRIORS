// Visible areas are a presentation of existing authorized routes, not an ACL.
export const CLUB_AREAS=Object.freeze([
 {id:'home',label:'Inicio',icon:'home',routes:['dashboard']},
 {id:'people',label:'Personas',icon:'users',routes:['members','enrollments','requests']},
 {id:'training',label:'Entrenamiento',icon:'calendar',routes:['sessions','groups','catalog','attendance','progress','tracking','events']},
 {id:'finance',label:'Finanzas',icon:'wallet',routes:['finance','reminders']},
 {id:'community',label:'Mi comunidad',icon:'network',routes:['communications','community']},
 {id:'material',label:'Material',icon:'package',routes:['material']},
 {id:'administration',label:'Administración',icon:'settings',routes:['users','settings','documents','archive','federation-admin','plans-services','scopes','assist','migrations','profile']}
]);
export function clubAreas(navItems=[]){
 const allowed=new Map(navItems.map(x=>[x.id,x]));
 // A member's personal profile remains in the account navigation, not administration.
 const staff=allowed.has('users')||allowed.has('settings')||allowed.has('scopes');
 return CLUB_AREAS.map(area=>({...area,items:area.routes.filter(id=>id!=='profile'||staff).map(id=>allowed.get(id)).filter(Boolean)})).filter(area=>area.items.length);
}
export function clubAreaForRoute(navItems,route){return clubAreas(navItems).find(area=>area.items.some(item=>item.id===route))||null;}
