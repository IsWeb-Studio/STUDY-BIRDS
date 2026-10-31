import axios, {AxiosError, type InternalAxiosRequestConfig} from 'axios';
import {expect,it} from 'vitest';
import {dashboardLoading,installDashboardLoading} from './dashboardLoading';
const response=(config:InternalAxiosRequestConfig)=>({data:{count:42},status:200,statusText:'OK',headers:{},config});
it('tracks overlapping reads by route, clears errors, and ignores auth/background reads and writes',async()=>{
  const doneA=dashboardLoading.begin('/admin/a'),doneB=dashboardLoading.begin('/admin/b');
  doneA();doneA();expect(dashboardLoading.count('/admin/a')).toBe(0);expect(dashboardLoading.count('/admin/b')).toBe(1);doneB();
  for(const [route,method,url] of [['/','get','/admin/stats'],['/admin/a','post','/admin/stats'],['/admin/a','get','/shared-read/summary'],['/admin/a','get','/auth/me']]){const done=dashboardLoading.begin(route,method,url);expect(dashboardLoading.count(route)).toBe(0);done();}
  const client=axios.create({adapter:async()=>{throw new Error('offline');}});installDashboardLoading(client,()=>'/admin/fail');
  await expect(client.get('/admin/stats')).rejects.toThrow('offline');expect(dashboardLoading.count('/admin/fail')).toBe(0);
});
it('keeps the original route busy through session renewal without tracking its retry against a new route',async()=>{
  let route='/admin/old',attempts=0,complete!:()=>void;
  const client=axios.create({adapter:async config=>{
    if(attempts++===0)throw new AxiosError('expired','ERR_BAD_REQUEST',config,undefined,{...response(config),status:401});
    await new Promise<void>(resolve=>{complete=resolve;});return response(config);
  }});
  client.interceptors.response.use(undefined,error=>client.request(error.config));
  installDashboardLoading(client,()=>route);
  const request=client.get('/admin/stats');
  while(!complete)await Promise.resolve();
  route='/admin/new';expect(dashboardLoading.count('/admin/old')).toBe(1);expect(dashboardLoading.count(route)).toBe(0);
  complete();await request;expect(dashboardLoading.count('/admin/old')).toBe(0);
});
it('clears cancelled reads and does not install duplicate tracking',async()=>{
  let complete!:(value:ReturnType<typeof response>)=>void,config!:InternalAxiosRequestConfig;
  const client=axios.create({adapter:c=>{config=c;return new Promise(resolve=>{complete=resolve;});}});
  installDashboardLoading(client,()=>'/admin/cancel');installDashboardLoading(client,()=>'/admin/cancel');
  const controller=new AbortController(),request=client.get('/admin/stats',{signal:controller.signal});
  while(!complete)await Promise.resolve();expect(dashboardLoading.count('/admin/cancel')).toBe(1);
  controller.abort();complete(response(config));await expect(request).rejects.toMatchObject({code:'ERR_CANCELED'});
  expect(dashboardLoading.count('/admin/cancel')).toBe(0);
});
