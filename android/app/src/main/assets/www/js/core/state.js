export const state = {
  session:null, route:'dashboard', busy:false, error:null, warning:null,
  trace:[], diagnostics:null, certification:null, capabilities:new Set(), unreadNotificationCount:0, unreadKombaxCount:0, unreadMessageCount:0,
  selectedSocioId:localStorage.getItem('uw2_selected_socio')||null, moduleCache:new Map(),
  pushTrace(entry){
    this.trace.unshift({at:new Date().toISOString(),...entry});
    this.trace=this.trace.slice(0,120);
    try{sessionStorage.setItem('uw2_trace',JSON.stringify(this.trace.slice(0,60)))}catch{}
  },
  clearError(){this.error=null;this.warning=null;},
  selectSocio(id){this.selectedSocioId=id||null;try{if(id)localStorage.setItem('uw2_selected_socio',id);else localStorage.removeItem('uw2_selected_socio')}catch{}},
  setCapabilities(operations=[]){this.capabilities=new Set(Array.isArray(operations)?operations:[])},
  can(operation){return this.capabilities.has(operation)},
  clearTenantState(){this.moduleCache.clear();this.selectedSocioId=null;this.unreadNotificationCount=0;this.unreadKombaxCount=0;this.unreadMessageCount=0;try{localStorage.removeItem('uw2_selected_socio')}catch{}}
};
