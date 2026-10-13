import { useLocation } from "react-router-dom";
import { LanguageRouteSync } from "../components/seo/LanguageRouteSync";
import { FloatingAssistant } from "../components/FloatingAssistant";
import { LeadCapturePrompt } from "../components/LeadCapturePrompt";
import { AppRoutes } from "../routes/AppRoutes";
import { ConnectivityBanner } from "../components/ConnectivityBanner";

export default function App() {
  const { pathname } = useLocation();
  const accountFlow = ["/login", "/register", "/forgot-password", "/account/security", "/mobile-sign-in"].includes(pathname);
  return (
    <>
      <ConnectivityBanner />
      <LanguageRouteSync />
      <AppRoutes />
      {!accountFlow ? <><LeadCapturePrompt /><FloatingAssistant /></> : null}
    </>
  );
}
