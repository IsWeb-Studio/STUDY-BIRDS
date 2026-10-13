const express = require("express");
const cors = require("cors");
const morgan = require("morgan");
const path = require("path");

const authRoutes = require("./routes/authRoutes");
const studentRoutes = require("./routes/studentRoutes");
const partnerRoutes = require("./routes/partnerRoutes");
const universityRoutes = require("./routes/universityRoutes");
const programRoutes = require("./routes/programRoutes");
const applicationRoutes = require("./routes/applicationRoutes");
const adminRoutes = require("./routes/adminRoutes");
const contentRoutes = require("./routes/contentRoutes");
const { notFound, errorHandler } = require("./middleware/errorMiddleware");
const { isDatabaseReady } = require("./config/db");
const {
  buildRobotsTxt,
  buildSitemapXml,
} = require("./utils/exhibitionSeo");
const ExhibitionArticle = require("./models/ExhibitionArticle");

const app = express();

const normalizeOrigin = (value) => value.trim().replace(/\/+$/, "");

const parseAllowedOrigins = () => {
  const configuredOrigins = [process.env.CLIENT_URL, process.env.CLIENT_URLS]
    .filter(Boolean)
    .flatMap((value) => value.split(","))
    .map(normalizeOrigin)
    .filter(Boolean);

  return new Set([
    ...configuredOrigins,
    "https://studybirds.net",
    "https://www.studybirds.net",
    "https://study-birds-web.onrender.com",
    "http://localhost:5173",
    "http://127.0.0.1:5173",
  ]);
};

const allowedOrigins = parseAllowedOrigins();

app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin || allowedOrigins.has(normalizeOrigin(origin))) {
        callback(null, true);
        return;
      }

      callback(new Error("Origin not allowed by CORS"));
    },
    credentials: true,
  })
);
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(morgan("dev"));
app.use((req, res, next) => {
  const startedAt = process.hrtime.bigint();

  res.on("finish", () => {
    const elapsedMs = Number(process.hrtime.bigint() - startedAt) / 1_000_000;
    console.log(`[perf] ${req.method} ${req.originalUrl} ${res.statusCode} - ${elapsedMs.toFixed(2)}ms`);
  });

  next();
});
app.use("/uploads", express.static(path.resolve(process.cwd(), process.env.UPLOAD_DIR || "src/uploads")));

app.get("/ping", (req, res) => {
  res.status(200).type("text/plain").send("OK");
});

app.get("/api/health", (req, res) => {
  res.json({ status: "ok", service: "study-birds-api" });
});

const requireDatabaseConnection = (req, res, next) => {
  if (isDatabaseReady()) {
    next();
    return;
  }

  res.status(503).json({
    message: "Database is not ready yet. Please try again shortly.",
  });
};

app.get("/robots.txt", (req, res) => {
  res.type("text/plain");
  res.send(buildRobotsTxt());
});

app.get("/sitemap.xml", requireDatabaseConnection, async (req, res, next) => {
  try {
    const articles = await ExhibitionArticle.find({ published: true }).lean();
    res.type("application/xml");
    res.send(buildSitemapXml(articles));
  } catch (error) {
    next(error);
  }
});

app.use("/api/mobile", requireDatabaseConnection, require("./routes/mobileRoutes"));
app.use("/api/mobile-workspace", requireDatabaseConnection, require("./routes/mobileWorkspaceRoutes"));
app.use("/api/mobile-security", requireDatabaseConnection, require("./routes/mobileSecurityRoutes"));
app.use("/api/auth", requireDatabaseConnection, authRoutes);
app.use("/api/students", requireDatabaseConnection, studentRoutes);
app.use("/api/partners", requireDatabaseConnection, partnerRoutes);
app.use("/api/universities", requireDatabaseConnection, universityRoutes);
app.use("/api/programs", requireDatabaseConnection, programRoutes);
app.use("/api/applications", requireDatabaseConnection, applicationRoutes);
app.use("/api/admin", requireDatabaseConnection, adminRoutes);
app.use("/api/content", requireDatabaseConnection, contentRoutes);

app.use(notFound);
app.use(errorHandler);

module.exports = app;
