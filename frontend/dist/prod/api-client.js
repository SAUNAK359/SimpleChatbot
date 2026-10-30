'use strict';
(function(){
  const cfg=window.AF_RUNTIME;
  class AFApiError extends Error{constructor(message,status=0,body=null,url=''){super(message);this.name='AFApiError';this.status=status;this.body=body;this.url=url}}
  const sleep=ms=>new Promise(r=>setTimeout(r,ms));
  const resolveRef=(root,schema)=>{if(!schema||!schema.$ref)return schema;const path=schema.$ref.replace(/^#\//,'').split('/');return path.reduce((v,k)=>v?.[k],root)};
  async function request(path,{method='GET',body,headers={},timeoutMs=cfg.requestTimeoutMs,retries}={}){
    const url=path.startsWith('http')?path:cfg.apiBaseUrl+path;
    const attempts=retries??(method==='GET'?cfg.maxGetRetries:0);
    for(let attempt=0;;attempt++){
      const controller=new AbortController();const timer=setTimeout(()=>controller.abort(),timeoutMs);
      try{
        const res=await fetch(url,{method,credentials:cfg.credentials,headers:{Accept:'application/json',...(body!==undefined?{'Content-Type':'application/json'}:{}),...headers},body:body===undefined?undefined:JSON.stringify(body),signal:controller.signal,cache:'no-store'});
        const type=res.headers.get('content-type')||'';let payload=null;
        if(res.status!==204){payload=type.includes('json')?await res.json().catch(()=>null):await res.text().catch(()=>null)}
        if(!res.ok){const message=(payload&&typeof payload==='object'&&(payload.detail||payload.message||payload.error))||`HTTP ${res.status}`;throw new AFApiError(String(message),res.status,payload,url)}
        return payload;
      }catch(err){
        const retryable=(err.name==='AbortError'||err instanceof TypeError||(err instanceof AFApiError&&[408,425,429,500,502,503,504].includes(err.status)));
        if(attempt<attempts&&retryable){await sleep(350*Math.pow(2,attempt));continue}
        if(err.name==='AbortError')throw new AFApiError('Request timed out',0,null,url);
        throw err;
      }finally{clearTimeout(timer)}
    }
  }
  let openapiPromise=null;
  async function openapi(){if(!openapiPromise)openapiPromise=request('/openapi.json',{timeoutMs:10000,retries:1});return openapiPromise}
  function deref(root,s){let cur=s;const seen=new Set();while(cur?.$ref&&!seen.has(cur.$ref)){seen.add(cur.$ref);cur=resolveRef(root,cur)}return cur}
  async function shapePayload(path,method,candidates){
    try{const spec=await openapi();const op=spec?.paths?.[path]?.[method.toLowerCase()];let schema=op?.requestBody?.content?.['application/json']?.schema;schema=deref(spec,schema);if(!schema)return candidates;
      const required=new Set(schema.required||[]),props=schema.properties||{};const out={};
      for(const [k,v] of Object.entries(candidates||{}))if(Object.prototype.hasOwnProperty.call(props,k)&&v!==undefined)out[k]=v;
      for(const k of required)if(out[k]===undefined&&candidates?.[k]!==undefined)out[k]=candidates[k];
      return Object.keys(out).length?out:candidates;
    }catch{return candidates}
  }
  const API={
    request,openapi,shapePayload,AFApiError,
    health:()=>request('/health/ready',{timeoutMs:5000,retries:0}),
    googleStart:()=>location.assign(cfg.apiBaseUrl+'/api/v1/auth/google/start'),
    githubOAuthStart:()=>location.assign(cfg.apiBaseUrl+'/api/v1/github/oauth/start'),
    githubInstallUrl:()=>request('/api/v1/github/install-url'),
    githubInstallations:()=>request('/api/v1/github/installations'),
    githubRepositories:id=>request(`/api/v1/github/installations/${encodeURIComponent(id)}/repositories`),
    projects:()=>request('/api/v1/projects'),
    createProject:async p=>request('/api/v1/projects',{method:'POST',body:await shapePayload('/api/v1/projects','post',p)}),
    branches:id=>request(`/api/v1/projects/${encodeURIComponent(id)}/branches`),
    analyze:id=>request(`/api/v1/projects/${encodeURIComponent(id)}/analyze`,{method:'POST'}),
    workflow:id=>request(`/api/v1/projects/${encodeURIComponent(id)}/workflow`),
    createRun:async(id,p)=>request(`/api/v1/projects/${encodeURIComponent(id)}/runs`,{method:'POST',body:await shapePayload('/api/v1/projects/{project_id}/runs','post',p)}),
    run:id=>request(`/api/v1/runs/${encodeURIComponent(id)}`),
    steps:id=>request(`/api/v1/runs/${encodeURIComponent(id)}/steps`),
    logs:id=>request(`/api/v1/runs/${encodeURIComponent(id)}/logs`),
    events:id=>request(`/api/v1/runs/${encodeURIComponent(id)}/events`),
    artifacts:id=>request(`/api/v1/runs/${encodeURIComponent(id)}/artifacts`),
    artifactUrl:(id,path)=>`${cfg.apiBaseUrl}/api/v1/runs/${encodeURIComponent(id)}/artifacts/${path.split('/').map(encodeURIComponent).join('/')}`,
    cancel:id=>request(`/api/v1/runs/${encodeURIComponent(id)}/cancel`,{method:'POST'}),
    rebuild:id=>request(`/api/v1/runs/${encodeURIComponent(id)}/rebuild`,{method:'POST'}),
    diagnose:id=>request(`/api/v1/runs/${encodeURIComponent(id)}/diagnose`,{method:'POST'}),
    repairPropose:id=>request(`/api/v1/runs/${encodeURIComponent(id)}/repair/propose`,{method:'POST'}),
    repairVerify:id=>request(`/api/v1/runs/${encodeURIComponent(id)}/repair/verify`,{method:'POST'}),
    repairRebuild:id=>request(`/api/v1/runs/${encodeURIComponent(id)}/repair/rebuild`,{method:'POST'})
  };
  window.AFApi=Object.freeze(API);
})();
