import {
  ArrowRight,
  Bot,
  Building2,
  FileText,
  GraduationCap,
  LayoutDashboard,
  LogIn,
  MessageSquare,
  SendHorizontal,
  UserRound,
  X,
  type LucideIcon,
} from "lucide-react";
import {
  useEffect,
  useMemo,
  useRef,
  useState,
  type FormEvent,
  type PointerEvent as ReactPointerEvent,
} from "react";
import { Link, useLocation } from "react-router-dom";
import { useAuth } from "../hooks/useAuth";
import { useLanguage } from "../hooks/useLanguage";
import { SITE_NAME } from "../seo/site";
import type { Role } from "../types";

interface AssistantAction {
  href: string;
  icon: LucideIcon;
  label: string;
}

interface AssistantContent {
  badge: string;
  title: string;
  description: string;
  tips: string[];
  actions: AssistantAction[];
}

interface ChatMessage {
  id: string;
  role: "assistant" | "user";
  text: string;
}

interface FloatingPosition {
  x: number;
  y: number;
}

const ASSISTANT_NAME = "bird Ai";
const ASSISTANT_POSITION_KEY = "studyBirdsAssistantPosition";

const getAssistantContent = (pathname: string, role: Role | undefined, language: "ar" | "en"): AssistantContent => {
  if (language === "ar") {
    if (pathname.startsWith("/student/documents")) {
      return {
        badge: "مساعد المستندات",
        title: "جهز ملفاتك قبل الإرسال",
        description: "ابدأ برفع جواز السفر والسجل الأكاديمي ثم راجع حالة كل ملف.",
        tips: ["ابدأ بالمستندات الأساسية", "انتقل بعدها إلى متابعة الطلبات"],
        actions: [
          { href: "/student", icon: UserRound, label: "الملف الشخصي" },
          { href: "/student/applications", icon: LayoutDashboard, label: "طلباتي" },
          { href: "/contact", icon: MessageSquare, label: "تواصل معنا" },
        ],
      };
    }

    if (pathname.startsWith("/student/applications")) {
      return {
        badge: "مساعد الطلبات",
        title: "تابع التقديم خطوة بخطوة",
        description: "راجع البرامج التي قدمت عليها وتأكد أن الملفات والبيانات مكتملة.",
        tips: ["راقب تغيّر الحالة", "أكمل أي مستند ناقص قبل طلب جديد"],
        actions: [
          { href: "/student/documents", icon: FileText, label: "المستندات" },
          { href: "/programs", icon: GraduationCap, label: "البرامج" },
          { href: "/contact", icon: MessageSquare, label: "اطلب مساعدة" },
        ],
      };
    }

    if (pathname.startsWith("/student")) {
      return {
        badge: "مساعد الطالب",
        title: "ابدأ من ملفك الشخصي",
        description: "إكمال بياناتك أولًا يجعل بقية رحلة التقديم أسرع وأسهل.",
        tips: ["أكمل البيانات الأساسية", "ثم ارفع المستندات قبل اختيار البرنامج"],
        actions: [
          { href: "/student/documents", icon: FileText, label: "رفع المستندات" },
          { href: "/student/applications", icon: LayoutDashboard, label: "متابعة الطلبات" },
          { href: "/programs", icon: GraduationCap, label: "استكشاف البرامج" },
        ],
      };
    }

    if (pathname.startsWith("/admin")) {
      return {
        badge: "مساعد الإدارة",
        title: "اختصارات للمهام المهمة",
        description: "تنقل بسرعة بين الطلبات والجامعات والبرامج والمحتوى.",
        tips: ["راجع الطلبات الجديدة أولًا", "حدّث المحتوى عند الحاجة"],
        actions: [
          { href: "/admin/applications", icon: FileText, label: "الطلبات" },
          { href: "/admin/universities", icon: Building2, label: "الجامعات" },
          { href: "/admin/programs", icon: GraduationCap, label: "البرامج" },
        ],
      };
    }

    if (pathname.startsWith("/programs")) {
      return {
        badge: "مساعد البرامج",
        title: "اختر البرنامج الأنسب لك",
        description: "قارن بين الرسوم وموعد الدراسة والمجال قبل فتح التفاصيل.",
        tips: ["قارن بين أكثر من برنامج", "راجع الجامعة المرتبطة قبل التقديم"],
        actions: [
          { href: "/universities", icon: Building2, label: "الجامعات" },
          { href: "/register", icon: UserRound, label: "أنشئ حسابك" },
          { href: "/contact", icon: MessageSquare, label: "استشارة سريعة" },
        ],
      };
    }

    if (pathname.startsWith("/universities")) {
      return {
        badge: "مساعد الجامعات",
        title: "اكتشف الجامعة المناسبة",
        description: "راجع المدينة والتكلفة والبرامج المرتبطة قبل اتخاذ القرار.",
        tips: ["ركز على المدينة والرسوم", "استكمل المقارنة عبر البرامج"],
        actions: [
          { href: "/programs", icon: GraduationCap, label: "البرامج المتاحة" },
          { href: "/destinations", icon: Building2, label: "وجهات الدراسة" },
          { href: "/contact", icon: MessageSquare, label: "اسأل الفريق" },
        ],
      };
    }

    if (pathname.startsWith("/login") || pathname.startsWith("/register") || pathname.startsWith("/forgot-password")) {
      return {
        badge: "مساعد البدء",
        title: "ابدأ رحلتك خلال دقائق",
        description: "أنشئ حسابًا أو سجّل الدخول لتحفظ بياناتك وتتابع طلباتك من مكان واحد.",
        tips: ["استخدم بريدًا إلكترونيًا فعالًا", "أكمل ملفك الشخصي بعد الدخول"],
        actions: [
          { href: "/register", icon: UserRound, label: "إنشاء حساب" },
          { href: "/login", icon: LogIn, label: "تسجيل الدخول" },
          { href: "/programs", icon: GraduationCap, label: "تصفح البرامج" },
        ],
      };
    }

    return {
      badge: `مساعد ${SITE_NAME}`,
      title: "كيف أساعدك اليوم؟",
      description:
        role === "student"
          ? "أرشدك إلى الخطوة التالية من ملفك الشخصي إلى المستندات والطلبات."
          : "استكشف البرامج والجامعات أو ابدأ حسابك وسأوجهك داخل المنصة.",
      tips:
        role === "student"
          ? ["ابدأ من الملف الشخصي", "ثم انتقل إلى المستندات والطلبات"]
          : ["ابدأ بالبرامج والجامعات", "أنشئ حسابًا عندما تصبح جاهزًا"],
      actions:
        role === "student"
          ? [
              { href: "/student", icon: UserRound, label: "ملفي الشخصي" },
              { href: "/student/documents", icon: FileText, label: "المستندات" },
              { href: "/student/applications", icon: LayoutDashboard, label: "الطلبات" },
            ]
          : [
              { href: "/programs", icon: GraduationCap, label: "البرامج" },
              { href: "/universities", icon: Building2, label: "الجامعات" },
              { href: "/contact", icon: MessageSquare, label: "تواصل معنا" },
            ],
    };
  }

  if (pathname.startsWith("/student/documents")) {
    return {
      badge: "Documents Assistant",
      title: "Prepare your files first",
      description: "Upload your passport and academic records, then review each file status.",
      tips: ["Start with core documents", "Move next to applications"],
      actions: [
        { href: "/student", icon: UserRound, label: "Profile" },
        { href: "/student/applications", icon: LayoutDashboard, label: "Applications" },
        { href: "/contact", icon: MessageSquare, label: "Contact us" },
      ],
    };
  }

  if (pathname.startsWith("/student/applications")) {
    return {
      badge: "Application Assistant",
      title: "Track every submission clearly",
      description: "Review the programs you applied to and make sure your data is complete.",
      tips: ["Watch status updates", "Complete missing files first"],
      actions: [
        { href: "/student/documents", icon: FileText, label: "Documents" },
        { href: "/programs", icon: GraduationCap, label: "Programs" },
        { href: "/contact", icon: MessageSquare, label: "Ask for help" },
      ],
    };
  }

  if (pathname.startsWith("/student")) {
    return {
      badge: "Student Assistant",
      title: "Start with your profile",
      description: "A complete profile makes the rest of your application journey easier.",
      tips: ["Finish your core details", "Upload documents before choosing a program"],
      actions: [
        { href: "/student/documents", icon: FileText, label: "Upload documents" },
        { href: "/student/applications", icon: LayoutDashboard, label: "Track applications" },
        { href: "/programs", icon: GraduationCap, label: "Explore programs" },
      ],
    };
  }

  if (pathname.startsWith("/admin")) {
    return {
      badge: "Admin Assistant",
      title: "Shortcuts for key tasks",
      description: "Move quickly across applications, universities, programs, and content.",
      tips: ["Review fresh applications first", "Update content when needed"],
      actions: [
        { href: "/admin/applications", icon: FileText, label: "Applications" },
        { href: "/admin/universities", icon: Building2, label: "Universities" },
        { href: "/admin/programs", icon: GraduationCap, label: "Programs" },
      ],
    };
  }

  if (pathname.startsWith("/programs")) {
    return {
      badge: "Program Assistant",
      title: "Choose the right-fit program",
      description: "Compare tuition, intake, and field of study before opening details.",
      tips: ["Compare more than one option", "Review the linked university"],
      actions: [
        { href: "/universities", icon: Building2, label: "Universities" },
        { href: "/register", icon: UserRound, label: "Create account" },
        { href: "/contact", icon: MessageSquare, label: "Quick consultation" },
      ],
    };
  }

  if (pathname.startsWith("/universities")) {
    return {
      badge: "University Assistant",
      title: "Explore the best-fit university",
      description: "Review city, cost, and linked programs before making a choice.",
      tips: ["Focus on city and tuition", "Continue comparison through programs"],
      actions: [
        { href: "/programs", icon: GraduationCap, label: "Programs" },
        { href: "/destinations", icon: Building2, label: "Destinations" },
        { href: "/contact", icon: MessageSquare, label: "Ask the team" },
      ],
    };
  }

  if (pathname.startsWith("/login") || pathname.startsWith("/register") || pathname.startsWith("/forgot-password")) {
    return {
      badge: "Getting Started",
      title: "Start your journey in minutes",
      description: "Create an account or sign in to save your data and track applications.",
      tips: ["Use an active email", "Complete your profile after signing in"],
      actions: [
        { href: "/register", icon: UserRound, label: "Create account" },
        { href: "/login", icon: LogIn, label: "Sign in" },
        { href: "/programs", icon: GraduationCap, label: "Browse programs" },
      ],
    };
  }

  return {
    badge: `${SITE_NAME} Assistant`,
    title: "How can I guide you today?",
    description:
      role === "student"
        ? "I can guide you through profile, documents, and applications."
        : "Explore programs and universities or start your account, and I will guide you.",
    tips:
      role === "student"
        ? ["Start with your profile", "Then move to documents and applications"]
        : ["Start with programs and universities", "Create an account when ready"],
    actions:
      role === "student"
        ? [
            { href: "/student", icon: UserRound, label: "My profile" },
            { href: "/student/documents", icon: FileText, label: "Documents" },
            { href: "/student/applications", icon: LayoutDashboard, label: "Applications" },
          ]
        : [
            { href: "/programs", icon: GraduationCap, label: "Programs" },
            { href: "/universities", icon: Building2, label: "Universities" },
            { href: "/contact", icon: MessageSquare, label: "Contact us" },
          ],
  };
};

const buildInitialMessages = (content: AssistantContent, language: "ar" | "en"): ChatMessage[] => [
  {
    id: "assistant-welcome",
    role: "assistant",
    text:
      language === "ar"
        ? `مرحبًا، أنا مساعدك داخل المنصة. ${content.description}`
        : `Hi, I am ${ASSISTANT_NAME}. ${content.description}`,
  },
];

const generateAssistantReply = (
  message: string,
  pathname: string,
  role: Role | undefined,
  language: "ar" | "en",
  content: AssistantContent
) => {
  const normalized = message.toLowerCase().trim();
  const reply = (ar: string, en: string) => (language === "ar" ? ar : en);

  if (
    normalized.includes("document") ||
    normalized.includes("file") ||
    normalized.includes("upload") ||
    normalized.includes("مستند") ||
    normalized.includes("ملف") ||
    normalized.includes("رفع")
  ) {
    return reply(
      "ابدأ برفع المستندات الأساسية مثل جواز السفر والسجل الأكاديمي ثم راجع حالة كل ملف من صفحة المستندات.",
      "Start by uploading core documents like your passport and academic records, then review each file status from the documents page."
    );
  }

  if (
    normalized.includes("apply") ||
    normalized.includes("application") ||
    normalized.includes("submit") ||
    normalized.includes("تقديم") ||
    normalized.includes("طلب") ||
    normalized.includes("إرسال")
  ) {
    if (role === "student") {
      return reply(
        "بما أنك مسجل كطالب، راجع ملفك ثم المستندات ثم افتح صفحة الطلبات لمتابعة أو إرسال أي تقديم جديد.",
        "Since you are signed in as a student, review your profile, then your documents, then open the applications page to track or submit applications."
      );
    }

    return reply(
      "للبدء في التقديم، أنشئ حسابًا أو سجل الدخول أولًا ثم اختر البرنامج المناسب.",
      "To start applying, create an account or sign in first, then choose a suitable program."
    );
  }

  if (
    normalized.includes("program") ||
    normalized.includes("major") ||
    normalized.includes("degree") ||
    normalized.includes("برنامج") ||
    normalized.includes("تخصص")
  ) {
    return reply(
      "صفحة البرامج هي أفضل مكان للمقارنة بين الرسوم وموعد الدراسة والمجال قبل فتح التفاصيل.",
      "The programs page is the best place to compare tuition, intake, and field of study before opening details."
    );
  }

  if (
    normalized.includes("university") ||
    normalized.includes("college") ||
    normalized.includes("جامعة") ||
    normalized.includes("كلية")
  ) {
    return reply(
      "استكشف الجامعات لمعرفة المدينة والتكلفة والبرامج المرتبطة بكل جامعة ثم انتقل إلى الخيار الأنسب لك.",
      "Explore universities to review city, cost, and linked programs, then move to the option that fits you best."
    );
  }

  if (
    normalized.includes("login") ||
    normalized.includes("register") ||
    normalized.includes("account") ||
    normalized.includes("حساب") ||
    normalized.includes("تسجيل") ||
    normalized.includes("دخول")
  ) {
    return reply(
      "إذا لم يكن لديك حساب بعد، ابدأ بإنشاء حساب جديد. وإذا كان لديك حساب بالفعل، سجل الدخول ثم أكمل بياناتك الأساسية.",
      "If you do not have an account yet, create one first. If you already have an account, sign in and complete your core details."
    );
  }

  if (
    normalized.includes("status") ||
    normalized.includes("track") ||
    normalized.includes("follow") ||
    normalized.includes("حالة") ||
    normalized.includes("متابعة")
  ) {
    return reply(
      "لمتابعة الحالة، افتح صفحة الطلبات حيث ستجد تطور كل طلب والملاحظات المرتبطة به.",
      "To track status, open the applications page where you can see each application's progress and notes."
    );
  }

  if (
    normalized.includes("profile") ||
    normalized.includes("gpa") ||
    normalized.includes("بيانات") ||
    normalized.includes("معدل")
  ) {
    return reply(
      "ابدأ بإكمال الملف الشخصي بدقة، خصوصًا معلومات الدراسة الحالية والمعدل والجنسية وموعد الدراسة المفضل.",
      "Start by completing your profile carefully, especially your current education, GPA, nationality, and preferred intake."
    );
  }

  if (
    normalized.includes("help") ||
    normalized.includes("support") ||
    normalized.includes("contact") ||
    normalized.includes("مساعدة") ||
    normalized.includes("دعم") ||
    normalized.includes("تواصل")
  ) {
    return reply(
      "إذا احتجت دعمًا مباشرًا، يمكنك استخدام صفحة التواصل. ويمكنني أيضًا توجيهك الآن إلى البرامج أو الجامعات أو خطوات التقديم المناسبة لك.",
      "If you need direct support, you can use the contact page. I can also guide you now toward programs, universities, or the best next step."
    );
  }

  if (pathname.startsWith("/admin")) {
    return reply(
      "أنت داخل مساحة الإدارة، لذلك أوصي بمراجعة الطلبات أولًا ثم الانتقال إلى الجامعات أو البرامج أو المحتوى.",
      "You are in the admin workspace, so I recommend reviewing applications first, then moving to universities, programs, or content."
    );
  }

  return reply(
    `يمكنني مساعدتك في البرامج والجامعات والتقديم والمستندات. ${content.title}`,
    `I can help with programs, universities, applications, and documents. ${content.title}`
  );
};

export const FloatingAssistant = () => {
  const { pathname } = useLocation();
  const { user } = useAuth();
  const { language, isRtl } = useLanguage();
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState("");
  const [isThinking, setIsThinking] = useState(false);
  const [isDragging, setIsDragging] = useState(false);
  const [buttonPosition, setButtonPosition] = useState<FloatingPosition | null>(null);
  const [viewportWidth, setViewportWidth] = useState(0);
  const content = useMemo(
    () => getAssistantContent(pathname, user?.role, language),
    [language, pathname, user?.role]
  );
  const [messages, setMessages] = useState<ChatMessage[]>(() => buildInitialMessages(content, language));
  const messagesRef = useRef<HTMLDivElement | null>(null);
  const floatingContainerRef = useRef<HTMLDivElement | null>(null);
  const dragOffsetRef = useRef({ x: 0, y: 0 });
  const dragStartRef = useRef({ x: 0, y: 0 });
  const activePointerIdRef = useRef<number | null>(null);
  const dragMovedRef = useRef(false);
  const activeRequestRef = useRef(0);
  const visibleMessages = messages.length ? messages : buildInitialMessages(content, language);

  const clampPosition = (position: FloatingPosition) => {
    if (typeof window === "undefined") {
      return position;
    }

    const floatingRect = floatingContainerRef.current?.getBoundingClientRect();
    const elementWidth = floatingRect?.width || 172;
    const elementHeight = floatingRect?.height || 56;
    const maxX = Math.max(12, window.innerWidth - elementWidth - 12);
    const bottomNavigationHeight = document.querySelector("[data-dashboard-bottom-nav]")?.getBoundingClientRect().height || 0;
    const maxY = Math.max(12, window.innerHeight - elementHeight - bottomNavigationHeight - 12);

    return {
      x: Math.min(Math.max(12, position.x), maxX),
      y: Math.min(Math.max(12, position.y), maxY),
    };
  };

  useEffect(() => {
    activeRequestRef.current += 1;
    setOpen(false);
    setDraft("");
    setIsThinking(false);
    setMessages(buildInitialMessages(content, language));
  }, [content, language, pathname]);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setOpen(false);
      }
    };

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  // Other screens (e.g. the student home "Bird AI" shortcut) open the assistant with this event.
  useEffect(() => {
    const openAssistant = () => setOpen(true);
    window.addEventListener("studybirds:open-assistant", openAssistant);
    return () => window.removeEventListener("studybirds:open-assistant", openAssistant);
  }, []);

  useEffect(() => {
    if (messagesRef.current) {
      messagesRef.current.scrollTop = messagesRef.current.scrollHeight;
    }
  }, [messages, isThinking]);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    const updateViewport = () => {
      setViewportWidth(window.innerWidth);
      setButtonPosition((current) => {
        if (current) {
          return clampPosition(current);
        }

        const storedPosition = window.localStorage.getItem(ASSISTANT_POSITION_KEY);
        if (storedPosition) {
          try {
            return clampPosition(JSON.parse(storedPosition) as FloatingPosition);
          } catch {
            window.localStorage.removeItem(ASSISTANT_POSITION_KEY);
          }
        }

        return clampPosition({
          x: window.innerWidth - 188,
          y: window.innerHeight - 80,
        });
      });
    };

    updateViewport();
    window.addEventListener("resize", updateViewport);
    return () => window.removeEventListener("resize", updateViewport);
  }, [pathname]);

  useEffect(() => {
    if (typeof window === "undefined" || !buttonPosition) {
      return;
    }

    window.localStorage.setItem(ASSISTANT_POSITION_KEY, JSON.stringify(buttonPosition));
  }, [buttonPosition]);

  useEffect(() => {
    if (!buttonPosition) {
      return;
    }

    setButtonPosition((current) => (current ? clampPosition(current) : current));
  }, [open]);

  useEffect(() => {
    const handlePointerMove = (event: PointerEvent) => {
      if (activePointerIdRef.current === null || event.pointerId !== activePointerIdRef.current) {
        return;
      }

      const deltaX = Math.abs(event.clientX - dragStartRef.current.x);
      const deltaY = Math.abs(event.clientY - dragStartRef.current.y);

      if (!dragMovedRef.current && deltaX < 6 && deltaY < 6) {
        return;
      }

      dragMovedRef.current = true;
      if (!isDragging) {
        setIsDragging(true);
      }

      setButtonPosition(
        clampPosition({
          x: event.clientX - dragOffsetRef.current.x,
          y: event.clientY - dragOffsetRef.current.y,
        })
      );
    };

    const stopDragging = (event?: PointerEvent) => {
      if (
        activePointerIdRef.current === null ||
        (event && event.pointerId !== activePointerIdRef.current)
      ) {
        return;
      }

      activePointerIdRef.current = null;
      window.setTimeout(() => {
        setIsDragging(false);
      }, 0);
    };

    window.addEventListener("pointermove", handlePointerMove);
    window.addEventListener("pointerup", stopDragging);
    window.addEventListener("pointercancel", stopDragging);

    return () => {
      window.removeEventListener("pointermove", handlePointerMove);
      window.removeEventListener("pointerup", stopDragging);
      window.removeEventListener("pointercancel", stopDragging);
    };
  }, []);

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    const nextMessage = draft.trim();
    if (!nextMessage || isThinking) {
      return;
    }

    const userMessage: ChatMessage = {
      id: `user-${Date.now()}`,
      role: "user",
      text: nextMessage,
    };

    const requestId = activeRequestRef.current + 1;

    activeRequestRef.current = requestId;
    setMessages((current) => [...current, userMessage]);
    setDraft("");
    setIsThinking(true);

    try {
      await new Promise((resolve) => window.setTimeout(resolve, 180));

      if (activeRequestRef.current !== requestId) {
        return;
      }

      const assistantMessage: ChatMessage = {
        id: `assistant-${Date.now()}`,
        role: "assistant",
        text: generateAssistantReply(
          nextMessage,
          pathname,
          user?.role,
          language,
          content
        ),
      };

      setMessages((current) => [...current, assistantMessage]);
    } finally {
      if (activeRequestRef.current === requestId) {
        setIsThinking(false);
      }
    }
  };

  const startDragging = (event: ReactPointerEvent<HTMLElement>) => {
    activePointerIdRef.current = event.pointerId;
    dragMovedRef.current = false;
    const rect = event.currentTarget.getBoundingClientRect();
    dragStartRef.current = {
      x: event.clientX,
      y: event.clientY,
    };
    dragOffsetRef.current = {
      x: event.clientX - rect.left,
      y: event.clientY - rect.top,
    };
    event.currentTarget.setPointerCapture(event.pointerId);
  };

  const handleButtonPointerDown = (event: ReactPointerEvent<HTMLButtonElement>) => {
    if (open) {
      return;
    }

    startDragging(event);
  };

  const handlePanelPointerDown = (event: ReactPointerEvent<HTMLDivElement>) => {
    if ((event.target as HTMLElement).closest("button, a, textarea")) {
      return;
    }

    startDragging(event);
  };

  const handleButtonClick = () => {
    if (dragMovedRef.current) {
      dragMovedRef.current = false;
      return;
    }

    setOpen((current) => !current);
  };

  const panelOpensToLeft = buttonPosition ? buttonPosition.x > viewportWidth / 2 : true;
  const panelOpensAbove = buttonPosition ? buttonPosition.y > 360 : true;

  return (
    <div className="pointer-events-none fixed inset-0 z-50" dir={isRtl ? "rtl" : "ltr"}>
      <div
        ref={floatingContainerRef}
        className="pointer-events-auto absolute"
        style={
          buttonPosition
            ? {
                left: `${buttonPosition.x}px`,
                top: `${buttonPosition.y}px`,
              }
            : {
                left: "1rem",
                bottom: "1.5rem",
              }
        }
      >
        {open ? (
          <div
            className={`absolute h-[min(72vh,680px)] w-[calc(100vw-2rem)] max-w-[420px] overflow-hidden rounded-[2rem] border border-white/70 bg-white shadow-[0_30px_90px_rgba(10,25,49,0.24)] backdrop-blur ${
              panelOpensToLeft ? "right-0" : "left-0"
            } ${panelOpensAbove ? "bottom-[calc(100%+0.75rem)]" : "top-[calc(100%+0.75rem)]"}`}
          >
            <div className="flex h-full flex-col bg-[linear-gradient(180deg,rgba(246,248,252,0.98)_0%,rgba(255,255,255,0.98)_100%)]">
              <div className="border-b border-slate-200/80 bg-fusion px-5 pb-4 pt-5 text-white">
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <div className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/12 px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.24em] text-brand-50">
                      <span className="h-2 w-2 rounded-full bg-emerald-300" />
                      {content.badge}
                    </div>
                    <div
                      className={`mt-4 flex items-center gap-3 ${isDragging ? "cursor-grabbing" : "cursor-grab"}`}
                      onPointerDown={handlePanelPointerDown}
                      style={{ touchAction: "none", userSelect: "none", WebkitUserSelect: "none" }}
                    >
                      <div className="inline-flex h-12 w-12 items-center justify-center rounded-2xl border border-white/20 bg-white/12 shadow-[inset_0_1px_0_rgba(255,255,255,0.18)]">
                        <Bot size={22} />
                      </div>
                      <div className="min-w-0">
                        <h3 className="truncate text-xl font-semibold">
                          {ASSISTANT_NAME}
                        </h3>
                        <p className="text-sm text-brand-100">
                          {language === "ar" ? "اسحبني لتغيير مكاني" : "Drag me to reposition"}
                        </p>
                      </div>
                    </div>
                    <p className="mt-4 max-w-sm text-sm leading-6 text-brand-50/95">{content.title}</p>
                  </div>

                  <button
                    type="button"
                    onClick={() => setOpen(false)}
                    className="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-full border border-white/20 bg-white/10 text-white transition hover:bg-white/20"
                    aria-label={language === "ar" ? `إغلاق ${ASSISTANT_NAME}` : `Close ${ASSISTANT_NAME}`}
                  >
                    <X size={18} />
                  </button>
                </div>

                <div className="mt-4 flex gap-2 overflow-x-auto pb-1">
                  {content.tips.slice(0, 2).map((tip) => (
                    <div
                      key={tip}
                      className="shrink-0 rounded-2xl border border-white/15 bg-white/10 px-3 py-2 text-xs leading-5 text-brand-50"
                    >
                      {tip}
                    </div>
                  ))}
                </div>
              </div>

              <div className="flex min-h-0 flex-1 flex-col overflow-hidden">
                <div className="min-h-0 flex-1 overflow-y-auto">
                  <div className="border-b border-slate-200/80 px-5 py-3">
                    <p className="text-xs font-semibold uppercase tracking-[0.22em] text-brand-700">
                      {language === "ar" ? "اختصارات سريعة" : "Quick shortcuts"}
                    </p>
                    <p className="mt-1 text-xs text-slate-500">
                      {language === "ar" ? "انتقل إلى أهم الخطوات مباشرة" : "Jump to the next important steps"}
                    </p>

                    <div className="mt-3 flex gap-2 overflow-x-auto pb-1">
                      {content.actions.map((action) => {
                        const Icon = action.icon;

                        return (
                          <Link
                            key={action.href}
                            to={action.href}
                            onClick={() => setOpen(false)}
                            className="group inline-flex shrink-0 items-center gap-2 rounded-full border border-slate-200 bg-white px-3 py-2 text-xs font-medium text-slate-700 transition hover:border-accent-300 hover:bg-accent-50 hover:text-accent-700"
                          >
                            <span className="inline-flex h-7 w-7 items-center justify-center rounded-full bg-accent-50 text-accent-700 transition group-hover:bg-accent-100">
                              <Icon size={14} />
                            </span>
                            <span>{action.label}</span>
                            <ArrowRight size={13} className={isRtl ? "rotate-180" : ""} />
                          </Link>
                        );
                      })}
                    </div>
                  </div>

                  <div className="px-4 pb-3 pt-2">
                    <div className="mb-2 flex items-center justify-between px-1">
                      <div>
                        <p className="text-xs font-semibold uppercase tracking-[0.22em] text-brand-700">
                          {language === "ar" ? "المحادثة" : "Conversation"}
                        </p>
                        <p className="mt-1 text-xs text-slate-500">
                          {language === "ar"
                            ? "اسأل عن البرامج أو التقديم أو المستندات"
                            : "Ask about programs, applications, or documents"}
                        </p>
                      </div>
                      <span className="rounded-full border border-brand-100 bg-brand-50 px-2.5 py-1 text-[11px] font-medium text-brand-700">
                        {language === "ar" ? "داخل المنصة" : "In-app"}
                      </span>
                    </div>

                    <div
                      ref={messagesRef}
                      className="min-h-[260px] space-y-3 overflow-y-auto rounded-[1.6rem] border border-slate-200 bg-[linear-gradient(180deg,#f6f8fc_0%,#ffffff_100%)] p-3 pr-2 sm:min-h-[300px]"
                      style={{ scrollbarGutter: "stable" }}
                    >
                      {visibleMessages.map((message) => (
                        <div
                          key={message.id}
                          className={`flex ${message.role === "user" ? "justify-end" : "justify-start"}`}
                        >
                          <div
                            className={`max-w-[88%] rounded-[1.4rem] px-4 py-3 text-sm leading-6 shadow-sm ${
                              message.role === "user"
                                ? "rounded-br-md bg-brand-900 text-white"
                                : "rounded-bl-md border border-slate-200 bg-white text-slate-700"
                            }`}
                          >
                            {message.text}
                          </div>
                        </div>
                      ))}

                      {isThinking ? (
                        <div className="flex justify-start">
                          <div className="rounded-[1.4rem] rounded-bl-md border border-slate-200 bg-white px-4 py-3 text-sm text-slate-500 shadow-sm">
                            {language === "ar" ? "أفكر في أفضل خطوة لك..." : "Thinking about the best next step..."}
                          </div>
                        </div>
                      ) : null}
                    </div>
                  </div>
                </div>

                <div className="shrink-0 border-t border-slate-200/80 bg-white px-4 pb-4 pt-2">
                  <form
                    onSubmit={handleSubmit}
                    className="rounded-[1.6rem] border border-slate-200 bg-slate-50 p-2 shadow-[inset_0_1px_0_rgba(255,255,255,0.65)]"
                  >
                    <div className="flex items-end gap-2">
                      <textarea
                        value={draft}
                        onChange={(event) => setDraft(event.target.value)}
                        rows={1}
                        placeholder={language === "ar" ? "اكتب رسالتك هنا..." : "Type your message here..."}
                        className="min-h-[48px] flex-1 resize-none border-0 bg-transparent px-3 py-3 text-sm text-slate-700 outline-none placeholder:text-slate-400 focus:ring-0"
                      />
                      <button
                        type="submit"
                        disabled={!draft.trim() || isThinking}
                        className="inline-flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-brand-900 text-white shadow-[0_12px_24px_rgba(10,25,49,0.18)] transition hover:bg-brand-700 disabled:cursor-not-allowed disabled:bg-slate-300 disabled:shadow-none"
                        aria-label={language === "ar" ? "إرسال الرسالة" : "Send message"}
                      >
                        <SendHorizontal size={18} className={isRtl ? "scale-x-[-1]" : ""} />
                      </button>
                    </div>
                  </form>
                </div>
              </div>
            </div>
          </div>
        ) : null}

        <button
          type="button"
          onPointerDown={handleButtonPointerDown}
          onClick={handleButtonClick}
          className={`inline-flex items-center gap-2 rounded-full bg-fusion px-3 py-2.5 text-sm font-semibold text-white shadow-[0_16px_40px_rgba(10,25,49,0.28)] transition hover:brightness-110 ${
            isDragging ? "cursor-grabbing" : "cursor-grab"
          }`}
          style={{ touchAction: "none", userSelect: "none", WebkitUserSelect: "none" }}
          aria-expanded={open}
          aria-label={language === "ar" ? `فتح ${ASSISTANT_NAME}` : `Open ${ASSISTANT_NAME}`}
        >
          <span className="inline-flex h-9 w-9 items-center justify-center rounded-full bg-white/14">
            <Bot size={18} />
          </span>
          <span className="flex flex-col items-start leading-tight">
            <span>{ASSISTANT_NAME}</span>
            <span className="text-[11px] font-medium text-brand-100">
              {language === "ar" ? "اسحبني لأي مكان" : "Drag me anywhere"}
            </span>
          </span>
        </button>
      </div>
    </div>
  );
};
