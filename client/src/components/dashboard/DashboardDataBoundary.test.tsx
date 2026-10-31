// @vitest-environment jsdom
import {act,useEffect,useState} from 'react';
import {createRoot,type Root} from 'react-dom/client';
import {beforeEach,afterEach,expect,it,vi} from 'vitest';
import {DashboardDataBoundary} from './DashboardDataBoundary';
import {dashboardLoading} from '../../lib/dashboardLoading';
vi.mock('../../hooks/useLanguage',()=>({useLanguage:()=>({language:'en'})}));
let root:Root,host:HTMLDivElement;
beforeEach(()=>{
  vi.useFakeTimers();vi.stubGlobal('requestAnimationFrame',(fn:FrameRequestCallback)=>setTimeout(()=>fn(0),16));vi.stubGlobal('cancelAnimationFrame',clearTimeout);
  (globalThis as typeof globalThis & {IS_REACT_ACT_ENVIRONMENT:boolean}).IS_REACT_ACT_ENVIRONMENT=true;
  host=document.createElement('div');document.body.append(host);root=createRoot(host);
});
afterEach(()=>{act(()=>root.unmount());host.remove();vi.useRealTimers();vi.unstubAllGlobals();});
const Fixture=({route,read}:{route:string;read:Promise<string>})=>{
  const [value,setValue]=useState('0');
  useEffect(()=>{const done=dashboardLoading.begin(route);void read.then(setValue,()=>setValue('Unable to load')).finally(done);},[route,read]);
  return <p data-testid="data">{value}</p>;
};
it('reserves space until the first read settles and retains content on refresh',async()=>{
  let finish!:(value:string)=>void;const read=new Promise<string>(resolve=>{finish=resolve;});
  await act(async()=>{root.render(<DashboardDataBoundary route="/admin/loading"><Fixture route="/admin/loading" read={read}/></DashboardDataBoundary>);});
  await act(async()=>{await vi.advanceTimersByTimeAsync(17);});
  expect(host.querySelector('[role="status"]')?.textContent).toContain('Loading data');
  expect(host.querySelector('[data-testid="data"]')?.closest('[hidden]')).not.toBeNull();
  await act(async()=>{finish('42');});
  expect(host.querySelector('[role="status"]')).toBeNull();expect(host.querySelector('[data-testid="data"]')?.closest('[hidden]')).toBeNull();
  let done!:()=>void;await act(async()=>{done=dashboardLoading.begin('/admin/loading');});
  expect(host.querySelector('[role="status"]')?.textContent).toContain('Updating data');expect(host.querySelector('[data-testid="data"]')?.textContent).toBe('42');
  await act(async()=>{done();});expect(host.querySelector('[role="status"]')).toBeNull();
});
it('releases the loader on failure and on pages without network reads',async()=>{
  let fail!:(error:Error)=>void;const read=new Promise<string>((_,reject)=>{fail=reject;});
  await act(async()=>{root.render(<DashboardDataBoundary route="/admin/error"><Fixture route="/admin/error" read={read}/></DashboardDataBoundary>);});
  await act(async()=>{await vi.advanceTimersByTimeAsync(17);});
  await act(async()=>{fail(new Error('offline'));});
  expect(host.querySelector('[role="status"]')).toBeNull();expect(host.textContent).toContain('Unable to load');
  await act(async()=>{root.render(<DashboardDataBoundary key="static" route="/admin/static"><p>Settings</p></DashboardDataBoundary>);});
  await act(async()=>{await vi.advanceTimersByTimeAsync(17);});
  expect(host.querySelector('[role="status"]')).toBeNull();expect(host.textContent).toContain('Settings');
});
