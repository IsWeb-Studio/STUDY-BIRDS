import sections from "../constants/employeeSections.json";
import type { User } from "../types";
export const employeeSections = sections;
export const canAccessEmployeePage = (user: User, path: string) => {
  if (path === '/admin/crm-workspace') return true; // CRM independently checks the linked account and every module.
  const page = path.split("/").filter(Boolean)[1];
  return sections.some((section) => section.pages.includes(page) && user.permissions?.includes(section.key));
};
export const employeeHome = (user: Pick<User, "permissions"> & {crmLinked?:boolean}) => {
  const first = sections.find((section) => user.permissions?.includes(section.key));
  return first ? `/admin/${first.pages[0]}` : user.crmLinked ? '/admin/crm-workspace' : "/employee";
};
