import "dotenv/config";
import "express-async-errors";
import express from "express";
import { isSupabaseAccessTokenVerificationConfigured } from "./lib/supabase-auth.js";
import { isSupabaseConfigured } from "./lib/supabase.js";
import { apiRouter } from "./routes/api.js";

const authMode: "hybrid" | "strict" =
  process.env.AUTH_MODE === "strict"
    ? "strict"
    : process.env.AUTH_MODE === "hybrid"
      ? "hybrid"
      : process.env.NODE_ENV === "production"
        ? "strict"
        : "hybrid";

if (authMode === "strict" && isSupabaseConfigured() && !isSupabaseAccessTokenVerificationConfigured()) {
  console.error(
    "[FATAL] AUTH_MODE=strict 이고 Supabase가 설정된 경우 Bearer 검증에 " +
      "SUPABASE_JWT_SECRET(HS256) 또는 SUPABASE_URL(JWKS 폴백) 중 하나가 필요합니다."
  );
  process.exit(1);
}

const app = express();
app.use(express.json({ limit: "512kb" }));
/** 로컬 웹(Flutter web 등)에서 API 호출용 — 프로덕션에서는 출처 제한 필요 */
app.use((req, res, next) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,PATCH,PUT,DELETE,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization, x-user-id");
  if (req.method === "OPTIONS") {
    res.status(204).end();
    return;
  }
  next();
});
app.use("/", apiRouter);

const port = Number(process.env.PORT ?? 4000);
const listenHost = process.env.LISTEN_HOST ?? "0.0.0.0";
app.listen(port, listenHost, () => {
  console.log(`Badminton API listening on http://${listenHost}:${port}`);
});
