const clamp=(value,min,max)=>Math.min(max,Math.max(min,value));

function jittered(ms,ratio){
  const base=Math.max(0,Number(ms)||0),spread=base*clamp(Number(ratio)||0,0,.5);
  if(!spread)return Math.round(base);
  return Math.max(0,Math.round(base-spread+Math.random()*spread*2));
}

function classifyResult(result){
  if(result===false)return {ok:false,activity:false};
  if(result==='idle')return {ok:true,activity:false};
  if(result&&typeof result==='object'&&'ok' in result)return {ok:result.ok!==false,activity:result.activity!==false};
  return {ok:true,activity:true};
}

export function createAdaptivePoller(task,{
  activeMs=45000,
  hiddenMs=0,
  maxMs=600000,
  idleMaxMs=activeMs,
  idleAfter=2,
  jitterRatio=.12,
  wakeDelayMs=80
}={}){
  let timer=null,stopped=true,running=false,failures=0,idleStreak=0;
  const clear=()=>{if(timer){clearTimeout(timer);timer=null;}};
  const online=()=>typeof navigator==='undefined'||navigator.onLine!==false;
  const hidden=()=>typeof document!=='undefined'&&document.visibilityState==='hidden';
  const resetActivity=()=>{failures=0;idleStreak=0;};
  const baseDelay=()=>{
    if(!online())return null;
    if(hidden())return Number(hiddenMs)>0?Number(hiddenMs):null;
    const active=Math.max(250,Number(activeMs)||45000);
    if(failures>0)return Math.min(Number(maxMs)||600000,active*Math.pow(2,failures));
    const threshold=Math.max(1,Number(idleAfter)||1);
    const exponent=Math.max(0,idleStreak-threshold+1);
    return Math.min(Math.max(active,Number(idleMaxMs)||active),active*Math.pow(2,exponent));
  };
  const schedule=(delay=null)=>{
    clear();if(stopped)return;
    const next=delay==null?baseDelay():delay;
    if(next==null)return;
    timer=setTimeout(()=>run(false),jittered(next,jitterRatio));
  };
  const run=async(force=false)=>{
    if(stopped||running)return false;
    if(!online()){schedule();return false;}
    if(hidden()&&Number(hiddenMs)<=0&&!force){schedule();return false;}
    running=true;let classified={ok:false,activity:false};
    try{classified=classifyResult(await task());}
    catch{classified={ok:false,activity:false};}
    finally{
      if(classified.ok){
        failures=0;
        idleStreak=classified.activity?0:clamp(idleStreak+1,0,12);
      }else{
        failures=clamp(failures+1,0,8);
      }
      running=false;schedule();
    }
    return classified.ok;
  };
  const wake=()=>{if(stopped)return;resetActivity();schedule(wakeDelayMs);};
  const onVisibility=()=>{if(hidden())schedule();else wake();};
  const onOnline=()=>wake();
  const onOffline=()=>schedule();
  return {
    start({immediate=true}={}){
      if(!stopped)return;stopped=false;
      if(typeof window!=='undefined'){window.addEventListener('online',onOnline);window.addEventListener('offline',onOffline);}
      if(typeof document!=='undefined')document.addEventListener('visibilitychange',onVisibility);
      if(immediate)run(true);else schedule();
    },
    stop(){
      if(stopped)return;stopped=true;clear();
      if(typeof window!=='undefined'){window.removeEventListener('online',onOnline);window.removeEventListener('offline',onOffline);}
      if(typeof document!=='undefined')document.removeEventListener('visibilitychange',onVisibility);
    },
    trigger(){if(stopped)return;resetActivity();run(true);},
    markActive(){resetActivity();if(!stopped)schedule(activeMs);},
    get failures(){return failures;},
    get idleStreak(){return idleStreak;}
  };
}
