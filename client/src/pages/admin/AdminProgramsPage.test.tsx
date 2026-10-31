// @vitest-environment jsdom
import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { beforeEach, afterEach, expect, it, vi } from "vitest";
import { AdminProgramsPage } from "./AdminProgramsPage";
import { programService } from "../../services/programService";
import { universityService } from "../../services/universityService";
import { adminService } from "../../services/adminService";
vi.mock("../../hooks/useLanguage",()=>({useLanguage:()=>({language:"en",t:(key:string)=>key})}));
vi.mock("../../components/admin/ArticleContentFields",()=>({ArticleContentFields:()=>null}));
vi.mock("../../lib/sharedReadState",()=>({markStaffRecord:async()=>({})}));
vi.mock("../../lib/api",()=>({getApiAssetUrl:(url:string)=>url}));
vi.mock("../../services/programService",()=>({programService:{getAll:vi.fn(),getById:vi.fn(),update:vi.fn(),create:vi.fn(),remove:vi.fn()}}));
vi.mock("../../services/universityService",()=>({universityService:{getOptions:vi.fn()}}));
vi.mock("../../services/adminService",()=>({adminService:{getStudyFields:vi.fn()}}));
const university={_id:"u",name:"University",slug:"university"};
const program={_id:"p",title:"Physics",slug:"physics",university,degreeLevel:"Bachelor",fieldOfStudy:"Science",__v:7};
const response={items:[program],pagination:{page:1,limit:20,total:100,totalPages:5,hasNextPage:true,hasPreviousPage:false}};
let root:Root,host:HTMLDivElement;
beforeEach(()=>{
  vi.useFakeTimers();vi.resetAllMocks();
  (globalThis as typeof globalThis & {IS_REACT_ACT_ENVIRONMENT:boolean}).IS_REACT_ACT_ENVIRONMENT=true;
  Element.prototype.scrollIntoView=vi.fn();
  vi.mocked(programService.getAll).mockResolvedValue(response);
  vi.mocked(programService.getById).mockResolvedValue(program);
  vi.mocked(programService.update).mockResolvedValue({...program,__v:8});
  vi.mocked(universityService.getOptions).mockResolvedValue([university]);
  vi.mocked(adminService.getStudyFields).mockResolvedValue([{_id:"s",name:"Science"}]);
  host=document.createElement("div");document.body.append(host);root=createRoot(host);
});
afterEach(()=>{act(()=>root.unmount());host.remove();vi.useRealTimers();});
const render=async()=>{await act(async()=>{root.render(<AdminProgramsPage/>);});};
const button=(text:string)=>[...host.querySelectorAll('button')].find(b=>b.textContent?.trim()===text)!;
it('loads a bounded page even if a lookup fails, with paging and debounced server search',async()=>{
  vi.mocked(universityService.getOptions).mockRejectedValue(new Error('Lookup unavailable'));
  await render();expect(host.textContent).toContain('Physics');
  expect(programService.getAll).toHaveBeenCalledWith({page:1,limit:20,keyword:'',adminSearch:true},expect.any(AbortSignal));
  await act(async()=>{button('Next').click();});
  expect(programService.getAll).toHaveBeenLastCalledWith(expect.objectContaining({page:2}),expect.any(AbortSignal));
  const input=host.querySelector('input')!;
  await act(async()=>{Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value')!.set!.call(input,'University');input.dispatchEvent(new Event('input',{bubbles:true}));});
  await act(async()=>{await vi.advanceTimersByTimeAsync(300);});
  expect(programService.getAll).toHaveBeenLastCalledWith(expect.objectContaining({page:1,keyword:'University'}),expect.any(AbortSignal));
});
it('confirms the saved revision immediately without waiting for a catalog refresh',async()=>{
  await render();await act(async()=>{button('Edit').click();});
  vi.mocked(programService.getAll).mockReturnValue(new Promise(()=>{}));
  await act(async()=>{host.querySelector('form')!.dispatchEvent(new Event('submit',{bubbles:true,cancelable:true}));});
  expect(programService.update).toHaveBeenCalledWith('p',expect.objectContaining({expectedVersion:7}));
  expect(host.textContent).toContain('Program saved successfully.');
  expect(host.querySelector('form')).toBeNull();
  expect(universityService.getOptions).toHaveBeenCalledTimes(1);
  expect(adminService.getStudyFields).toHaveBeenCalledTimes(1);
});
it('retains the editor when the write itself is rejected',async()=>{
  await render();await act(async()=>{button('Edit').click();});
  vi.mocked(programService.update).mockRejectedValue(new Error('Revision conflict'));
  await act(async()=>{host.querySelector('form')!.dispatchEvent(new Event('submit',{bubbles:true,cancelable:true}));});
  expect(host.querySelector('form')).not.toBeNull();expect(host.textContent).toContain('Revision conflict');
  expect(host.textContent).not.toContain('Program saved successfully.');
});

it('never reports a failed save when only the follow-up list request fails',async()=>{
  await render();await act(async()=>{button('Edit').click();});
  vi.mocked(programService.getAll).mockRejectedValue(new Error('Read timeout'));
  await act(async()=>{host.querySelector('form')!.dispatchEvent(new Event('submit',{bubbles:true,cancelable:true}));});
  expect(host.textContent).toContain('Program saved successfully.');
  expect(host.textContent).toContain('Saved, but the list could not refresh.');
  expect(host.querySelector('form')).toBeNull();
  expect(programService.update).toHaveBeenCalledTimes(1);
});
