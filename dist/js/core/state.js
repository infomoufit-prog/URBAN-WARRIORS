export const state = {
  session:null, route:'dashboard', busy:false, error:null, warning:null,
  trace:[], diagnostics:null, certification:null, selectedSocioId:localStorage.getItem('uw2_selected_socio')||null, moduleCache:new Map(),
  pushTrace(entry){
    this.trace.unshift({at:new Date().toISOString(),...entry});
    this.trace=this.trace.slice(0,120);
    try{sessionStorage.setItem('uw2_trace',JSON.stringify(this.trace.slice(0,60)))}catch{}
  },
  clearError(){this.error=null;this.warning=null;},
  selectSocio(id){this.selectedSocioId=id||null;try{if(id)localStorage.setItem('uw2_selected_socio',id);else localStorage.removeItem('uw2_selected_socio')}catch{}}
};
