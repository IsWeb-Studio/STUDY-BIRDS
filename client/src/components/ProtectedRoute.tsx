import { Navigate, Outlet, useLocation } from "react-router-dom";
import { canAccessEmployeePage, employeeHome } from "../utils/employeeAccess";
import { useLanguage } from "../hooks/useLanguage";
import { useAuth } from "../hooks/useAuth";
import { LoadingSpinner } from "./LoadingSpinner";
import { OfflineState } from "./OfflineState";
import type { Role } from "../types";

export const ProtectedRoute = ({ roles }: { roles?: Role[] }) => {
  const { user, loading, sessionUnverified, refreshSession } = useAuth();
  const { pathname } = useLocation();
  const { language } = useLanguage();

  if (loading) {
    return <LoadingSpinner />;
  }

  // A saved login that could not be verified (offline / server down) must not
  // bounce the user to the login page or sign them out.
  if (!user && sessionUnverified) {
    return <OfflineState onRetry={() => refreshSession().catch(() => undefined)} />;
  }

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  if (roles && !roles.includes(user.role)) {
    return <Navigate to="/" replace />;
  }

  if (user.role === "employee" && pathname !== "/account/security" && !canAccessEmployeePage(user, pathname)) {
    const home = employeeHome(user);
    if (home !== pathname) return <Navigate to={`${home}?lang=${language}`} replace />;
    return <div className="container-shell py-12"><p>{language === "ar" ? "لم يتم تعيين أقسام لحسابك. تواصل مع الأدمن لتحديد صلاحياتك." : "No sections assigned. Contact your administrator to request access."}</p><a href="/">{language === "ar" ? "الرئيسية" : "Home"}</a></div>;
  }
  return <Outlet />;
};
