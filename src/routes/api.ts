import { randomUUID } from "node:crypto";
import { Router, type Request } from "express";
import {
  MembershipStatus as Ms,
  Prisma,
  type Group,
  type User as UserRow,
  type Venue as VenueRow
} from "@prisma/client";
import {
  type Favorite,
  type PlayRoundRecord,
  type PlaySession,
  type SkillLevel,
  type SocialProvider
} from "../data/store.js";
import {
  buildDoublesRound,
  skillRankInRange,
  type MatchingMode
} from "../services/play-matching.service.js";
import { nextId } from "../utils/id.js";
import { distanceKm } from "../utils/geo.js";
import { pushInAppNotification } from "../utils/in-app-notification.js";
import { MembershipService } from "../services/membership.service.js";
import { tryAttachSupabaseSessionToSocialResponse } from "../lib/mock-supabase-session.js";
import { isSupabaseConfigured, getSupabaseAdmin, getSupabaseAnon } from "../lib/supabase.js";
import { isSupabaseJwtSecretConfigured, verifySupabaseAccessToken } from "../lib/supabase-auth.js";
import { prisma } from "../lib/prisma.js";
import {
  PrismaGroupRepository,
  PrismaMembershipNotificationService,
  PrismaMembershipRepository
} from "../repositories/prisma-membership.repository.js";
import { DEFAULT_DEV_ACTOR_USER_ID } from "../constants/dev-seed-ids.js";

const membershipRepo = new PrismaMembershipRepository();
const groupRepo = new PrismaGroupRepository();
const notificationService = new PrismaMembershipNotificationService();
const membershipService = new MembershipService(membershipRepo, groupRepo, notificationService);

const approvedMembershipCount = { where: { status: Ms.approved } };

type AuthMode = "hybrid" | "strict";

type AugmentedRequest = Request & {
  actorUserId?: string;
  /** Bearer 토큰이 있었으나 비었거나 Supabase JWT 검증에 실패함 */
  authBearerRejected?: boolean;
};

const authMode: AuthMode =
  process.env.AUTH_MODE === "strict"
    ? "strict"
    : process.env.AUTH_MODE === "hybrid"
      ? "hybrid"
      : process.env.NODE_ENV === "production"
        ? "strict"
        : "hybrid";

function mockSocialAllowed(): boolean {
  if (process.env.ALLOW_MOCK_SOCIAL === "true") return true;
  if (process.env.ALLOW_MOCK_SOCIAL === "false") return false;
  return process.env.NODE_ENV !== "production";
}

function isPublicRoute(req: Request): boolean {
  const path = req.path;
  const method = req.method.toUpperCase();
  if (method === "GET" && path === "/health") return true;
  if (method === "GET" && path === "/venues") return true;
  if (method === "GET" && /^\/venues\/[^/]+$/.test(path)) return true;
  if (method === "GET" && /^\/venues\/[^/]+\/groups$/.test(path)) return true;
  if (method === "GET" && path === "/groups") return true;
  if (method === "GET" && /^\/groups\/[^/]+$/.test(path)) return true;
  if (method === "GET" && path.startsWith("/auth/social/") && path.endsWith("/start")) return true;
  if (method === "POST" && /^\/auth\/social\/[^/]+$/.test(path)) return true;
  if (method === "POST" && path.startsWith("/auth/social/") && path.endsWith("/callback")) return true;
  return false;
}

function getActorUserId(req: Request): string {
  const r = req as AugmentedRequest;
  if (r.actorUserId) return r.actorUserId;
  if (authMode === "strict") {
    return "";
  }
  const raw = r.headers["x-user-id"];
  if (typeof raw === "string" && raw.trim().length > 0) return raw.trim();
  const fromEnv = process.env.DEV_ACTOR_USER_ID?.trim();
  return fromEnv && fromEnv.length > 0 ? fromEnv : DEFAULT_DEV_ACTOR_USER_ID;
}

function numFromDecimal(v: Prisma.Decimal | null | undefined): number | null {
  if (v == null) return null;
  return v.toNumber();
}

function venueToApi(row: VenueRow) {
  const amenities = (row.amenities ?? {}) as Record<string, unknown>;
  return {
    id: row.id,
    name: row.name,
    address: row.address,
    courtCount: row.courtCount,
    parking: amenities.parking === true,
    ratingAvg: row.ratingAvg.toNumber(),
    lat: numFromDecimal(row.latitude) ?? 0,
    lng: numFromDecimal(row.longitude) ?? 0
  };
}

function userToApi(u: UserRow) {
  return {
    id: u.id,
    email: u.email,
    nickname: u.nickname,
    photoUrl: u.photoUrl,
    skillLevel: u.skillLevel,
    role: u.role
  };
}

type GroupWithApprovedCount = Group & {
  _count: { memberships: number };
};

function groupToApi(g: GroupWithApprovedCount) {
  return {
    id: g.id,
    name: g.name,
    hostUserId: g.hostUserId,
    homeVenueId: g.homeVenueId ?? "",
    photoUrl: g.photoUrl,
    levelMin: g.levelMin,
    levelMax: g.levelMax,
    maxMembers: g.maxMembers,
    memberCount: g._count.memberships,
    status: g.status,
    requiresApproval: g.requiresApproval,
    description: g.description ?? ""
  };
}

function playSessionToApi(s: {
  id: string;
  groupId: string;
  hostUserId: string;
  name: string;
  venueId: string;
  startsAt: Date;
  endsAt: Date;
  courtCount: number;
  levelMin: SkillLevel;
  levelMax: SkillLevel;
  maxParticipants: number;
  participantIds: Prisma.JsonValue;
  waitlistIds: Prisma.JsonValue;
  defaultMatchingMode: string;
  currentRound: number;
  rounds: Prisma.JsonValue;
}): PlaySession {
  return {
    id: s.id,
    groupId: s.groupId,
    hostUserId: s.hostUserId,
    name: s.name,
    venueId: s.venueId,
    startsAt: s.startsAt.toISOString(),
    endsAt: s.endsAt.toISOString(),
    courtCount: s.courtCount,
    levelMin: s.levelMin,
    levelMax: s.levelMax,
    maxParticipants: s.maxParticipants,
    participantIds: s.participantIds as string[],
    waitlistIds: s.waitlistIds as string[],
    defaultMatchingMode: s.defaultMatchingMode === "random" ? "random" : "balanced",
    currentRound: s.currentRound,
    rounds: s.rounds as unknown as PlayRoundRecord[]
  };
}

async function loadGroupWithCount(groupId: string): Promise<GroupWithApprovedCount | null> {
  const g = await prisma.group.findUnique({
    where: { id: groupId },
    include: { _count: { select: { memberships: approvedMembershipCount } } }
  });
  return g;
}

async function mergeUserAccounts(
  tx: Prisma.TransactionClient,
  sourceUserId: string,
  targetUserId: string,
  reason: string
): Promise<void> {
  const sourceCp = await tx.coachProfile.findUnique({ where: { userId: sourceUserId } });
  const targetCp = await tx.coachProfile.findUnique({ where: { userId: targetUserId } });
  if (sourceCp) {
    if (targetCp) {
      await tx.coachProfile.delete({ where: { userId: sourceUserId } });
    } else {
      await tx.coachProfile.update({
        where: { userId: sourceUserId },
        data: { userId: targetUserId }
      });
    }
  }

  const memberships = await tx.membership.findMany({ where: { userId: sourceUserId } });
  for (const m of memberships) {
    const conflict = await tx.membership.findUnique({
      where: { userId_groupId: { userId: targetUserId, groupId: m.groupId } }
    });
    if (conflict) {
      await tx.membership.delete({ where: { id: m.id } });
    } else {
      await tx.membership.update({ where: { id: m.id }, data: { userId: targetUserId } });
    }
  }

  await tx.notification.updateMany({
    where: { userId: sourceUserId },
    data: { userId: targetUserId }
  });

  await tx.lessonBooking.updateMany({
    where: { coachUserId: sourceUserId },
    data: { coachUserId: targetUserId }
  });
  await tx.lessonBooking.updateMany({
    where: { studentUserId: sourceUserId },
    data: { studentUserId: targetUserId }
  });

  await tx.socialAccount.updateMany({
    where: { userId: sourceUserId },
    data: { userId: targetUserId }
  });

  const favs = await tx.favorite.findMany({ where: { userId: sourceUserId } });
  for (const f of favs) {
    const dup = await tx.favorite.findUnique({
      where: {
        userId_targetType_targetId: {
          userId: targetUserId,
          targetType: f.targetType,
          targetId: f.targetId
        }
      }
    });
    if (dup) {
      await tx.favorite.delete({ where: { id: f.id } });
    } else {
      await tx.favorite.update({ where: { id: f.id }, data: { userId: targetUserId } });
    }
  }

  await tx.review.updateMany({
    where: { authorUserId: sourceUserId },
    data: { authorUserId: targetUserId }
  });

  await tx.lightningMatch.updateMany({
    where: { hostUserId: sourceUserId },
    data: { hostUserId: targetUserId }
  });

  await tx.chatMessage.updateMany({
    where: { userId: sourceUserId },
    data: { userId: targetUserId }
  });

  await tx.playSession.updateMany({
    where: { hostUserId: sourceUserId },
    data: { hostUserId: targetUserId }
  });

  const sessions = await tx.playSession.findMany();
  for (const s of sessions) {
    const p = [...(s.participantIds as string[])];
    const w = [...(s.waitlistIds as string[])];
    if (!p.includes(sourceUserId) && !w.includes(sourceUserId)) continue;
    await tx.playSession.update({
      where: { id: s.id },
      data: {
        participantIds: p.map((id) => (id === sourceUserId ? targetUserId : id)),
        waitlistIds: w.map((id) => (id === sourceUserId ? targetUserId : id))
      }
    });
  }

  await tx.group.updateMany({
    where: { hostUserId: sourceUserId },
    data: { hostUserId: targetUserId }
  });

  await tx.event.updateMany({
    where: { createdBy: sourceUserId },
    data: { createdBy: targetUserId }
  });

  const followsAsFollower = await tx.userFollow.findMany({ where: { followerId: sourceUserId } });
  for (const f of followsAsFollower) {
    const dup = await tx.userFollow.findUnique({
      where: { followerId_followeeId: { followerId: targetUserId, followeeId: f.followeeId } }
    });
    if (dup) await tx.userFollow.delete({ where: { id: f.id } });
    else await tx.userFollow.update({ where: { id: f.id }, data: { followerId: targetUserId } });
  }

  const followsAsFollowee = await tx.userFollow.findMany({ where: { followeeId: sourceUserId } });
  for (const f of followsAsFollowee) {
    const dup = await tx.userFollow.findUnique({
      where: { followerId_followeeId: { followerId: f.followerId, followeeId: targetUserId } }
    });
    if (dup) await tx.userFollow.delete({ where: { id: f.id } });
    else await tx.userFollow.update({ where: { id: f.id }, data: { followeeId: targetUserId } });
  }

  await tx.directMessage.updateMany({
    where: { fromUserId: sourceUserId },
    data: { fromUserId: targetUserId }
  });
  await tx.directMessage.updateMany({
    where: { toUserId: sourceUserId },
    data: { toUserId: targetUserId }
  });

  await tx.accountMergeLog.create({
    data: {
      fromUserId: sourceUserId,
      toUserId: targetUserId,
      reason
    }
  });

  await tx.user.delete({ where: { id: sourceUserId } });
}

export const apiRouter = Router();

apiRouter.use(async (req, _res, next) => {
  const authHeader = req.headers.authorization;
  const r = req as AugmentedRequest;
  if (!authHeader?.startsWith("Bearer ")) {
    return next();
  }
  const token = authHeader.slice("Bearer ".length).trim();
  if (!token) {
    r.authBearerRejected = true;
    return next();
  }
  if (!isSupabaseJwtSecretConfigured()) {
    return next();
  }
  try {
    const { sub } = await verifySupabaseAccessToken(token);
    r.actorUserId = sub;
  } catch {
    r.authBearerRejected = true;
  }
  next();
});

apiRouter.use((req, res, next) => {
  if (isPublicRoute(req)) return next();
  const r = req as AugmentedRequest;
  if (r.authBearerRejected) {
    return res.status(401).json({ message: "Invalid or expired Supabase access token." });
  }
  next();
});

apiRouter.use((req, res, next) => {
  if (authMode !== "strict") return next();
  if (isPublicRoute(req)) return next();
  const actorFromToken = (req as AugmentedRequest).actorUserId;
  if (actorFromToken) return next();
  return res.status(401).json({ message: "Supabase authentication required (Bearer access token)." });
});

apiRouter.get("/health", (_req, res) => {
  res.json({
    ok: true,
    supabase: isSupabaseConfigured(),
    supabaseJwt: isSupabaseJwtSecretConfigured(),
    databaseConfigured: Boolean(process.env.DATABASE_URL?.trim())
  });
});

apiRouter.get("/auth/social/:provider/start", (req, res) => {
  const provider = req.params.provider as SocialProvider;
  const redirectUri = `https://auth.example.com/${provider}/callback`;
  return res.json({
    provider,
    redirectUri,
    state: nextId("state")
  });
});

apiRouter.post("/auth/social/:provider", async (req, res) => {
  if (!mockSocialAllowed()) {
    return res.status(403).json({ message: "Mock social authentication is disabled in this environment." });
  }
  const provider = req.params.provider as SocialProvider;
  const { providerUserId, email, emailVerified, nickname } = req.body ?? {};
  if (!providerUserId) return res.status(400).json({ message: "providerUserId is required" });

  const linked = await prisma.socialAccount.findUnique({
    where: { provider_providerUserId: { provider, providerUserId: String(providerUserId) } }
  });
  if (linked) {
    const user = await prisma.user.findUnique({ where: { id: linked.userId } });
    if (!user) return res.status(404).json({ message: "User not found" });
    const u = userToApi(user);
    const response: Record<string, unknown> = {
      accessToken: `mock-token-${u.id}`,
      user: u
    };
    const admin = getSupabaseAdmin();
    const anon = getSupabaseAnon();
    if (admin && anon) {
      await tryAttachSupabaseSessionToSocialResponse({
        admin,
        anon,
        prismaUserId: user.id,
        prismaEmail: user.email,
        response
      });
    }
    return res.json(response);
  }

  if (email) {
    const existing = await prisma.user.findFirst({
      where: { email: { equals: String(email), mode: "insensitive" } }
    });
    if (existing) {
      return res.status(409).json({ message: "Account linking required", existingUserId: existing.id });
    }
  }

  const photoUrl =
    typeof req.body?.photoUrl === "string" && String(req.body.photoUrl).trim().length > 0
      ? String(req.body.photoUrl).trim().slice(0, 2048)
      : null;

  const loginEmail =
    email && String(email).trim().length > 0
      ? String(email).trim().toLowerCase()
      : `${String(provider)}_${String(providerUserId)}@mock.bdminton.internal`.toLowerCase();

  const admin = getSupabaseAdmin();
  const anon = getSupabaseAnon();

  if (admin && anon) {
    const password = randomUUID();
    const { data: authData, error: authErr } = await admin.auth.admin.createUser({
      email: loginEmail,
      password,
      email_confirm: true,
      user_metadata: { nickname: nickname ?? `${provider}-user` }
    });
    if (authErr || !authData?.user) {
      return res.status(502).json({
        message: "Supabase auth user creation failed",
        detail: authErr?.message ?? "unknown"
      });
    }
    const userId = authData.user.id;
    const created = await prisma.user.create({
      data: {
        id: userId,
        email: email ?? null,
        nickname: nickname ?? `${provider}-user`,
        photoUrl,
        skillLevel: "beginner",
        role: "member",
        socialAccounts: {
          create: {
            provider,
            providerUserId: String(providerUserId),
            email: email ?? null,
            emailVerified: Boolean(emailVerified)
          }
        }
      },
      include: { socialAccounts: true }
    });
    const u = userToApi(created);
    const response: Record<string, unknown> = {
      accessToken: `mock-token-${u.id}`,
      user: u
    };
    const { data: sess, error: signErr } = await anon.auth.signInWithPassword({
      email: loginEmail,
      password
    });
    if (!signErr && sess?.session) {
      response.supabaseAccessToken = sess.session.access_token;
      response.supabaseRefreshToken = sess.session.refresh_token;
    }
    return res.json(response);
  }

  const created = await prisma.user.create({
    data: {
      email: email ?? null,
      nickname: nickname ?? `${provider}-user`,
      photoUrl,
      skillLevel: "beginner",
      role: "member",
      socialAccounts: {
        create: {
          provider,
          providerUserId: String(providerUserId),
          email: email ?? null,
          emailVerified: Boolean(emailVerified)
        }
      }
    },
    include: { socialAccounts: true }
  });

  const u = userToApi(created);
  return res.json({
    accessToken: `mock-token-${u.id}`,
    user: u
  });
});

apiRouter.post("/auth/social/:provider/callback", (req, res) => {
  if (!mockSocialAllowed()) {
    return res.status(403).json({ message: "Mock social authentication is disabled in this environment." });
  }
  const provider = req.params.provider as SocialProvider;
  const { code } = req.body ?? {};
  if (!code) return res.status(400).json({ message: "code is required" });
  return res.json({
    provider,
    message: "OAuth callback accepted",
    nextEndpoint: `/auth/social/${provider}`
  });
});

apiRouter.post("/auth/link/:provider", async (req, res) => {
  const provider = req.params.provider as SocialProvider;
  const userId = getActorUserId(req);
  const { providerUserId, email, emailVerified } = req.body ?? {};
  if (!providerUserId) return res.status(400).json({ message: "providerUserId is required" });
  const taken = await prisma.socialAccount.findFirst({
    where: { provider, providerUserId: String(providerUserId), NOT: { userId } }
  });
  if (taken) return res.status(409).json({ message: "Already linked to another user" });

  const linked = await prisma.socialAccount.create({
    data: {
      userId,
      provider,
      providerUserId: String(providerUserId),
      email: email ?? null,
      emailVerified: Boolean(emailVerified)
    }
  });
  return res.json({
    id: linked.id,
    userId: linked.userId,
    provider: linked.provider,
    providerUserId: linked.providerUserId,
    email: linked.email,
    emailVerified: linked.emailVerified,
    linkedAt: linked.linkedAt.toISOString()
  });
});

apiRouter.post("/auth/merge", async (req, res) => {
  const actorUserId = getActorUserId(req);
  const { sourceUserId, reason } = req.body ?? {};
  if (!sourceUserId || !reason) return res.status(400).json({ message: "sourceUserId and reason are required" });
  if (sourceUserId === actorUserId) return res.status(400).json({ message: "Invalid sourceUserId" });
  const source = await prisma.user.findUnique({ where: { id: sourceUserId } });
  const target = await prisma.user.findUnique({ where: { id: actorUserId } });
  if (!source || !target) return res.status(404).json({ message: "User not found" });

  try {
    await prisma.$transaction(async (tx) => {
      await mergeUserAccounts(tx, sourceUserId, actorUserId, String(reason));
    });
  } catch (e) {
    console.error(e);
    return res.status(409).json({ message: "Merge failed (constraints or missing rows)." });
  }

  return res.json({
    accessToken: `mock-token-${target.id}`,
    user: userToApi(target),
    mergedFrom: sourceUserId,
    reason
  });
});

apiRouter.get("/users/me", async (req, res) => {
  const user = await prisma.user.findUnique({ where: { id: getActorUserId(req) } });
  if (!user) return res.status(404).json({ message: "User not found" });
  return res.json(userToApi(user));
});

apiRouter.patch("/users/me", async (req, res) => {
  const id = getActorUserId(req);
  const body = req.body ?? {};
  const data: Prisma.UserUpdateInput = {};
  if (typeof body.nickname === "string" && body.nickname.trim().length > 0) {
    data.nickname = body.nickname.trim().slice(0, 80);
  }
  if (body.photoUrl === null || body.photoUrl === "") {
    data.photoUrl = null;
  } else if (typeof body.photoUrl === "string") {
    const raw = body.photoUrl.trim();
    data.photoUrl = raw.length > 0 ? raw.slice(0, 2048) : null;
  }
  if (Object.keys(data).length === 0) {
    const u = await prisma.user.findUnique({ where: { id } });
    if (!u) return res.status(404).json({ message: "User not found" });
    return res.json(userToApi(u));
  }
  try {
    const u = await prisma.user.update({ where: { id }, data });
    return res.json(userToApi(u));
  } catch {
    return res.status(404).json({ message: "User not found" });
  }
});

apiRouter.get("/venues", async (req, res) => {
  const { area, minCourtCount, parking, sort } = req.query;
  const rows = await prisma.venue.findMany();
  let items = rows.map(venueToApi);
  if (typeof area === "string" && area.length > 0) items = items.filter((v) => v.address.includes(area));
  if (typeof minCourtCount === "string") items = items.filter((v) => v.courtCount >= Number(minCourtCount));
  if (typeof parking === "string") items = items.filter((v) => v.parking === (parking === "true"));
  if (sort === "rating") items.sort((a, b) => b.ratingAvg - a.ratingAvg);
  return res.json({ items, nextCursor: null });
});

apiRouter.get("/venues/:venueId", async (req, res) => {
  const row = await prisma.venue.findUnique({ where: { id: req.params.venueId } });
  if (!row) return res.status(404).json({ message: "Venue not found" });
  const v = venueToApi(row);
  return res.json({
    ...v,
    openHours: row.openHours ?? {},
    amenities: { ...(typeof row.amenities === "object" && row.amenities ? row.amenities : {}), parking: v.parking }
  });
});

apiRouter.get("/venues/:venueId/groups", async (req, res) => {
  const venueId = req.params.venueId;
  const groups = await prisma.group.findMany({
    where: { homeVenueId: venueId },
    include: { _count: { select: { memberships: approvedMembershipCount } } }
  });
  return res.json({ items: groups.map(groupToApi) });
});

apiRouter.get("/groups", async (_req, res) => {
  const groups = await prisma.group.findMany({
    include: { _count: { select: { memberships: approvedMembershipCount } } }
  });
  res.json({ items: groups.map(groupToApi) });
});

apiRouter.get("/groups/:groupId", async (req, res) => {
  const g = await loadGroupWithCount(req.params.groupId);
  if (!g) return res.status(404).json({ message: "Group not found" });
  return res.json(groupToApi(g));
});

apiRouter.patch("/groups/:groupId", async (req, res) => {
  const actor = getActorUserId(req);
  const g0 = await prisma.group.findUnique({ where: { id: req.params.groupId } });
  if (!g0) return res.status(404).json({ message: "Group not found" });
  if (g0.hostUserId !== actor) {
    return res.status(403).json({ message: "Only host can update group profile" });
  }
  const body = req.body ?? {};
  const data: Prisma.GroupUpdateInput = {};
  if (typeof body.name === "string" && body.name.trim().length > 0) {
    data.name = body.name.trim().slice(0, 80);
  }
  if (typeof body.description === "string") {
    data.description = String(body.description).slice(0, 2000);
  }
  if (body.photoUrl === null) {
    data.photoUrl = null;
  } else if (typeof body.photoUrl === "string") {
    const raw = body.photoUrl.trim();
    data.photoUrl = raw.length > 0 ? raw.slice(0, 2048) : null;
  }
  const updated = await prisma.group.update({
    where: { id: req.params.groupId },
    data,
    include: { _count: { select: { memberships: approvedMembershipCount } } }
  });
  return res.json(groupToApi(updated));
});

apiRouter.post("/groups", async (req, res) => {
  const userId = getActorUserId(req);
  const input = req.body ?? {};
  const photoUrlRaw = input.photoUrl;
  const photoUrl =
    typeof photoUrlRaw === "string" && String(photoUrlRaw).trim().length > 0
      ? String(photoUrlRaw).trim().slice(0, 2048)
      : null;
  let resolvedHomeVenueId =
    typeof input.homeVenueId === "string" && input.homeVenueId.length > 0 ? input.homeVenueId : null;
  if (!resolvedHomeVenueId) {
    const firstVenue = await prisma.venue.findFirst({ orderBy: { createdAt: "asc" } });
    if (!firstVenue) {
      return res.status(400).json({ message: "No venues in database; create a venue first or pass homeVenueId." });
    }
    resolvedHomeVenueId = firstVenue.id;
  }
  const group = await prisma.group.create({
    data: {
      name: input.name ?? "새 모임",
      hostUserId: userId,
      homeVenueId: resolvedHomeVenueId,
      photoUrl,
      levelMin: input.levelMin ?? "beginner",
      levelMax: input.levelMax ?? "advanced",
      maxMembers: Number(input.maxMembers ?? 20),
      requiresApproval: Boolean(input.requiresApproval ?? true),
      description: input.description ?? "",
      status: "recruiting",
      memberships: {
        create: {
          userId,
          status: Ms.approved,
          role: "member",
          decidedAt: new Date(),
          decidedBy: userId
        }
      }
    },
    include: { _count: { select: { memberships: approvedMembershipCount } } }
  });
  return res.status(201).json(groupToApi(group));
});

apiRouter.post("/groups/:groupId/join-requests", async (req, res) => {
  const userId = getActorUserId(req);
  const groupId = req.params.groupId;
  const group = await prisma.group.findUnique({ where: { id: groupId } });
  if (!group) return res.status(404).json({ message: "Group not found" });
  if (group.status === "closed") return res.status(409).json({ message: "Group closed" });
  try {
    const created = await membershipRepo.createApplied({ userId, groupId });
    return res.status(201).json(created);
  } catch {
    return res.status(409).json({ message: "Already applied or member" });
  }
});

apiRouter.get("/groups/:groupId/join-requests", async (req, res) => {
  const actor = getActorUserId(req);
  const group = await prisma.group.findUnique({ where: { id: req.params.groupId } });
  if (!group) return res.status(404).json({ message: "Group not found" });
  if (group.hostUserId !== actor) return res.status(403).json({ message: "Forbidden" });
  const items = await prisma.membership.findMany({ where: { groupId: group.id } });
  return res.json({ items });
});

apiRouter.patch("/groups/:groupId/join-requests/:membershipId", async (req, res) => {
  const decision: "approve" | "reject" = req.body?.decision;
  if (decision !== "approve" && decision !== "reject") {
    return res.status(400).json({ message: "decision must be approve or reject" });
  }
  try {
    const updated = await membershipService.decideApplication({
      membershipId: req.params.membershipId,
      actorUserId: getActorUserId(req),
      decision
    });
    return res.json(updated);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    const status = message.includes("capacity") || message.includes("Only applied") ? 409 : 403;
    return res.status(status).json({ message });
  }
});

apiRouter.get("/notifications", async (req, res) => {
  const userId = getActorUserId(req);
  const rows = await prisma.notification.findMany({
    where: { userId },
    orderBy: { createdAt: "desc" }
  });
  const items = rows.map((n) => ({
    id: n.id,
    userId: n.userId,
    type: n.type,
    payload: n.payload as Record<string, unknown>,
    readAt: n.readAt ? n.readAt.toISOString() : null,
    createdAt: n.createdAt.toISOString()
  }));
  return res.json({ items });
});

apiRouter.patch("/notifications/:notificationId/read", async (req, res) => {
  const userId = getActorUserId(req);
  const item = await prisma.notification.updateMany({
    where: { id: req.params.notificationId, userId },
    data: { readAt: new Date() }
  });
  if (item.count === 0) return res.status(404).json({ message: "Notification not found" });
  const n = await prisma.notification.findFirst({ where: { id: req.params.notificationId, userId } });
  if (!n) return res.status(404).json({ message: "Notification not found" });
  return res.json({
    id: n.id,
    userId: n.userId,
    type: n.type,
    payload: n.payload as Record<string, unknown>,
    readAt: n.readAt?.toISOString() ?? null,
    createdAt: n.createdAt.toISOString()
  });
});

apiRouter.get("/favorites", async (req, res) => {
  const userId = getActorUserId(req);
  const rows = await prisma.favorite.findMany({ where: { userId } });
  const items = rows.map((f) => ({
    id: f.id,
    userId: f.userId,
    targetType: f.targetType,
    targetId: f.targetId,
    createdAt: f.createdAt.toISOString()
  }));
  return res.json({ items });
});

apiRouter.post("/favorites/:targetType/:targetId", async (req, res) => {
  const userId = getActorUserId(req);
  const { targetType, targetId } = req.params;
  if (targetType !== "venue" && targetType !== "group" && targetType !== "user") {
    return res.status(400).json({ message: "Invalid targetType" });
  }
  try {
    const created = await prisma.favorite.create({
      data: {
        userId,
        targetType,
        targetId
      }
    });
    const item: Favorite = {
      id: created.id,
      userId,
      targetType: created.targetType as Favorite["targetType"],
      targetId: created.targetId,
      createdAt: created.createdAt.toISOString()
    };
    return res.status(201).json(item);
  } catch (e) {
    if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === "P2002") {
      const existing = await prisma.favorite.findUnique({
        where: {
          userId_targetType_targetId: { userId, targetType: targetType as never, targetId }
        }
      });
      if (existing) {
        return res.status(201).json({
          id: existing.id,
          userId,
          targetType: existing.targetType,
          targetId: existing.targetId,
          createdAt: existing.createdAt.toISOString()
        });
      }
    }
    throw e;
  }
});

apiRouter.delete("/favorites/:targetType/:targetId", async (req, res) => {
  const userId = getActorUserId(req);
  await prisma.favorite.deleteMany({
    where: {
      userId,
      targetType: req.params.targetType as never,
      targetId: req.params.targetId
    }
  });
  return res.status(204).send();
});

apiRouter.get("/lightning-matches", async (_req, res) => {
  const rows = await prisma.lightningMatch.findMany();
  res.json({
    items: rows.map((l) => ({
      id: l.id,
      hostUserId: l.hostUserId,
      venueId: l.venueId,
      startAt: l.startAt.toISOString(),
      endAt: l.endAt.toISOString(),
      capacity: l.capacity,
      level: l.level,
      status: l.status,
      note: l.note
    }))
  });
});

apiRouter.post("/lightning-matches", async (req, res) => {
  const userId = getActorUserId(req);
  const input = req.body ?? {};
  const venueId =
    typeof input.venueId === "string" && input.venueId.length > 0
      ? input.venueId
      : (await prisma.venue.findFirst({ orderBy: { createdAt: "asc" } }))?.id;
  if (!venueId) return res.status(400).json({ message: "venueId required or seed venues first." });
  const item = await prisma.lightningMatch.create({
    data: {
      hostUserId: userId,
      venueId,
      startAt: new Date(input.startAt ?? Date.now()),
      endAt: new Date(input.endAt ?? Date.now() + 2 * 60 * 60 * 1000),
      capacity: Number(input.capacity ?? 4),
      level: input.level ?? "intermediate",
      status: "open",
      note: input.note ?? null
    }
  });
  return res.status(201).json({
    id: item.id,
    hostUserId: item.hostUserId,
    venueId: item.venueId,
    startAt: item.startAt.toISOString(),
    endAt: item.endAt.toISOString(),
    capacity: item.capacity,
    level: item.level,
    status: item.status,
    note: item.note
  });
});

apiRouter.get("/discover/meetups", async (req, res) => {
  const lat = Number(req.query.lat);
  const lng = Number(req.query.lng);
  const sort = req.query.sort === "time" ? "time" : "distance";
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return res.status(400).json({ message: "lat and lng query parameters are required" });
  }
  const now = new Date();
  const groups = await prisma.group.findMany({
    include: { _count: { select: { memberships: approvedMembershipCount } } }
  });
  const venues = await prisma.venue.findMany();
  const venueById = new Map(venues.map((v) => [v.id, v]));
  const sessions = await prisma.playSession.findMany({
    where: { startsAt: { gt: now } },
    orderBy: { startsAt: "asc" }
  });
  const nextByGroup = new Map<string, (typeof sessions)[0]>();
  for (const s of sessions) {
    if (!nextByGroup.has(s.groupId)) nextByGroup.set(s.groupId, s);
  }

  type Item = {
    group: ReturnType<typeof groupToApi>;
    venue: ReturnType<typeof venueToApi> | null;
    distanceKm: number | null;
    nextPlaySession: PlaySession | null;
  };

  const items: Item[] = groups.map((group) => {
    const g = groupToApi(group);
    const vrow = group.homeVenueId ? venueById.get(group.homeVenueId) : undefined;
    const venue = vrow ? venueToApi(vrow) : null;
    const distanceKmVal =
      venue != null ? distanceKm(lat, lng, venue.lat, venue.lng) : null;
    const s = nextByGroup.get(group.id);
    const nextPlaySession = s ? playSessionToApi(s) : null;
    return { group: g, venue, distanceKm: distanceKmVal, nextPlaySession };
  });

  if (sort === "distance") {
    items.sort(
      (a, b) => (a.distanceKm ?? Number.POSITIVE_INFINITY) - (b.distanceKm ?? Number.POSITIVE_INFINITY)
    );
  } else {
    items.sort((a, b) => {
      const ta = a.nextPlaySession
        ? new Date(a.nextPlaySession.startsAt).getTime()
        : Number.POSITIVE_INFINITY;
      const tb = b.nextPlaySession
        ? new Date(b.nextPlaySession.startsAt).getTime()
        : Number.POSITIVE_INFINITY;
      return ta - tb;
    });
  }
  return res.json({ items });
});

apiRouter.get("/feed", async (_req, res) => {
  const reviews = await prisma.review.findMany({
    orderBy: { createdAt: "desc" },
    take: 80
  });
  const authorIds = [...new Set(reviews.map((r) => r.authorUserId))];
  const authors = await prisma.user.findMany({ where: { id: { in: authorIds } } });
  const authorById = new Map(authors.map((u) => [u.id, userToApi(u)]));
  const items = reviews.map((r) => ({
    id: r.id,
    authorUserId: r.authorUserId,
    targetType: r.targetType,
    targetId: r.targetId,
    rating: r.rating,
    comment: r.comment,
    imageUrl: r.imageUrl,
    createdAt: r.createdAt.toISOString(),
    author: authorById.get(r.authorUserId) ?? null
  }));
  return res.json({ items });
});

apiRouter.post("/reviews", async (req, res) => {
  const userId = getActorUserId(req);
  const input = req.body ?? {};
  if (!input.targetType || !input.targetId || !input.rating) {
    return res.status(400).json({ message: "targetType, targetId, rating are required" });
  }
  const review = await prisma.review.create({
    data: {
      authorUserId: userId,
      targetType: input.targetType,
      targetId: input.targetId,
      rating: Number(input.rating),
      comment: input.comment ?? null,
      imageUrl:
        typeof input.imageUrl === "string" && input.imageUrl.length > 0 ? String(input.imageUrl) : null
    }
  });
  return res.status(201).json({
    id: review.id,
    authorUserId: review.authorUserId,
    targetType: review.targetType,
    targetId: review.targetId,
    rating: review.rating,
    comment: review.comment,
    imageUrl: review.imageUrl,
    createdAt: review.createdAt.toISOString()
  });
});

apiRouter.get("/groups/:groupId/play-sessions", async (req, res) => {
  const rows = await prisma.playSession.findMany({ where: { groupId: req.params.groupId } });
  return res.json({ items: rows.map(playSessionToApi) });
});

apiRouter.post("/groups/:groupId/play-sessions", async (req, res) => {
  const actor = getActorUserId(req);
  const group = await prisma.group.findUnique({ where: { id: req.params.groupId } });
  if (!group) return res.status(404).json({ message: "Group not found" });
  if (group.hostUserId !== actor) return res.status(403).json({ message: "Only host can create play sessions" });
  const body = req.body ?? {};
  const defaultMatchingMode: PlaySession["defaultMatchingMode"] =
    (body.defaultMatchingMode as MatchingMode) === "random" ? "random" : "balanced";
  const venueId = String(body.venueId ?? group.homeVenueId ?? "");
  if (!venueId) return res.status(400).json({ message: "venueId or group homeVenueId required" });
  const session = await prisma.playSession.create({
    data: {
      groupId: group.id,
      hostUserId: actor,
      name: String(body.name ?? "운동 일정"),
      venueId,
      startsAt: new Date(body.startsAt ?? Date.now()),
      endsAt: new Date(body.endsAt ?? Date.now() + 3 * 60 * 60 * 1000),
      courtCount: Math.max(1, Math.min(20, Number(body.courtCount ?? 2))),
      levelMin: (body.levelMin as SkillLevel) ?? "beginner",
      levelMax: (body.levelMax as SkillLevel) ?? "advanced",
      maxParticipants: Math.max(4, Math.min(64, Number(body.maxParticipants ?? 16))),
      participantIds: [],
      waitlistIds: [],
      defaultMatchingMode,
      currentRound: 0,
      rounds: []
    }
  });
  return res.status(201).json(playSessionToApi(session));
});

apiRouter.get("/play-sessions/:sessionId", async (req, res) => {
  const session = await prisma.playSession.findUnique({ where: { id: req.params.sessionId } });
  if (!session) return res.status(404).json({ message: "Play session not found" });
  const venueRow = await prisma.venue.findUnique({ where: { id: session.venueId } });
  return res.json({ ...playSessionToApi(session), venue: venueRow ? venueToApi(venueRow) : null });
});

apiRouter.post("/play-sessions/:sessionId/join", async (req, res) => {
  const userId = getActorUserId(req);
  const session = await prisma.playSession.findUnique({ where: { id: req.params.sessionId } });
  if (!session) return res.status(404).json({ message: "Play session not found" });
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) return res.status(404).json({ message: "User not found" });
  if (!skillRankInRange(user.skillLevel, session.levelMin, session.levelMax)) {
    return res.status(400).json({ message: "Skill level is outside this session's allowed range" });
  }
  const participantIds = [...(session.participantIds as string[])];
  const waitlistIds = [...(session.waitlistIds as string[])];
  if (participantIds.includes(userId)) {
    const updated = await prisma.playSession.findUnique({ where: { id: session.id } });
    return res.json({ session: playSessionToApi(updated!), status: "participant" });
  }
  if (waitlistIds.includes(userId)) {
    const updated = await prisma.playSession.findUnique({ where: { id: session.id } });
    return res.json({ session: playSessionToApi(updated!), status: "waitlist" });
  }
  if (participantIds.length < session.maxParticipants) {
    participantIds.push(userId);
  } else {
    waitlistIds.push(userId);
  }
  const saved = await prisma.playSession.update({
    where: { id: session.id },
    data: { participantIds, waitlistIds }
  });
  const status = participantIds.includes(userId) ? "participant" : "waitlist";
  return res.json({ session: playSessionToApi(saved), status });
});

apiRouter.post("/play-sessions/:sessionId/leave", async (req, res) => {
  const userId = getActorUserId(req);
  const session = await prisma.playSession.findUnique({ where: { id: req.params.sessionId } });
  if (!session) return res.status(404).json({ message: "Play session not found" });
  let participantIds = [...(session.participantIds as string[])];
  let waitlistIds = [...(session.waitlistIds as string[])];
  const wasParticipant = participantIds.includes(userId);
  participantIds = participantIds.filter((id) => id !== userId);
  waitlistIds = waitlistIds.filter((id) => id !== userId);
  const promoted: string[] = [];
  while (participantIds.length < session.maxParticipants && waitlistIds.length > 0) {
    const next = waitlistIds.shift();
    if (!next) break;
    const u = await prisma.user.findUnique({ where: { id: next } });
    if (u && skillRankInRange(u.skillLevel, session.levelMin, session.levelMax)) {
      participantIds.push(next);
      promoted.push(next);
    }
  }
  if (wasParticipant) {
    for (const pid of promoted) {
      await pushInAppNotification(pid, "play_session_promoted_from_waitlist", {
        playSessionId: session.id,
        groupId: session.groupId
      });
    }
    const openSeats = session.maxParticipants - participantIds.length;
    if (openSeats > 0) {
      const memberUserIds = await prisma.membership.findMany({
        where: {
          groupId: session.groupId,
          status: Ms.approved,
          userId: { notIn: [...participantIds, ...waitlistIds] }
        },
        select: { userId: true }
      });
      for (const uid of new Set(memberUserIds.map((m) => m.userId))) {
        await pushInAppNotification(uid, "play_session_spot_open", {
          playSessionId: session.id,
          groupId: session.groupId,
          openSeats
        });
      }
    }
  }
  const updated = await prisma.playSession.update({
    where: { id: session.id },
    data: { participantIds, waitlistIds }
  });
  return res.json(playSessionToApi(updated));
});

apiRouter.post("/play-sessions/:sessionId/remind-start", async (req, res) => {
  const actor = getActorUserId(req);
  const session = await prisma.playSession.findUnique({ where: { id: req.params.sessionId } });
  if (!session) return res.status(404).json({ message: "Play session not found" });
  if (session.hostUserId !== actor) {
    return res.status(403).json({ message: "Only host can send start reminders" });
  }
  const targets = [...new Set([...(session.participantIds as string[]), ...(session.waitlistIds as string[])])];
  for (const uid of targets) {
    await pushInAppNotification(uid, "play_session_start", {
      playSessionId: session.id,
      groupId: session.groupId,
      startsAt: session.startsAt.toISOString(),
      name: session.name
    });
  }
  return res.json({ ok: true, notifiedUserIds: targets });
});

apiRouter.post("/play-sessions/:sessionId/match", async (req, res) => {
  const actor = getActorUserId(req);
  const session = await prisma.playSession.findUnique({ where: { id: req.params.sessionId } });
  if (!session) return res.status(404).json({ message: "Play session not found" });
  if (session.hostUserId !== actor) return res.status(403).json({ message: "Only host can run matching" });
  const mode = (req.body?.mode as MatchingMode) ?? (session.defaultMatchingMode as MatchingMode);
  if (mode !== "random" && mode !== "balanced") {
    return res.status(400).json({ message: "mode must be random or balanced" });
  }
  const participantIds = session.participantIds as string[];
  if (participantIds.length < 4) {
    return res.status(409).json({ message: "At least 4 participants required for doubles matching" });
  }
  const currentRound = session.currentRound + 1;
  const getSkill = async (id: string): Promise<SkillLevel> => {
    const u = await prisma.user.findUnique({ where: { id } });
    return u?.skillLevel ?? "beginner";
  };
  const skillCache = new Map<string, SkillLevel>();
  const getSkillSync = (id: string): SkillLevel => skillCache.get(id) ?? "beginner";
  for (const id of participantIds) {
    skillCache.set(id, await getSkill(id));
  }
  const courts = buildDoublesRound(participantIds, getSkillSync, session.courtCount, mode, currentRound);
  const rounds = [...(session.rounds as unknown as PlayRoundRecord[])];
  const record: PlayRoundRecord = {
    round: currentRound,
    mode,
    courts,
    createdAt: new Date().toISOString()
  };
  rounds.push(record);
  const updated = await prisma.playSession.update({
    where: { id: session.id },
    data: { currentRound, rounds: rounds as unknown as Prisma.InputJsonValue }
  });
  return res.json({ session: playSessionToApi(updated), round: record });
});

apiRouter.get("/users", async (_req, res) => {
  const users = await prisma.user.findMany();
  return res.json({
    items: users.map((u) => ({
      id: u.id,
      nickname: u.nickname,
      photoUrl: u.photoUrl,
      skillLevel: u.skillLevel
    }))
  });
});

apiRouter.post("/users/:userId/follow", async (req, res) => {
  const followerId = getActorUserId(req);
  const followeeId = req.params.userId;
  if (followerId === followeeId) {
    return res.status(400).json({ message: "Cannot follow yourself" });
  }
  const peer = await prisma.user.findUnique({ where: { id: followeeId } });
  if (!peer) return res.status(404).json({ message: "User not found" });
  try {
    await prisma.userFollow.create({
      data: { followerId, followeeId }
    });
    return res.status(201).json({ ok: true });
  } catch (e) {
    if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === "P2002") {
      return res.json({ ok: true, already: true });
    }
    throw e;
  }
});

apiRouter.delete("/users/:userId/follow", async (req, res) => {
  const followerId = getActorUserId(req);
  const followeeId = req.params.userId;
  await prisma.userFollow.deleteMany({
    where: { followerId, followeeId }
  });
  return res.status(204).send();
});

apiRouter.get("/users/me/following", async (req, res) => {
  const me = getActorUserId(req);
  const edges = await prisma.userFollow.findMany({ where: { followerId: me } });
  const ids = edges.map((e) => e.followeeId);
  const users = await prisma.user.findMany({ where: { id: { in: ids } } });
  return res.json({ items: users.map(userToApi) });
});

apiRouter.get("/dm/inbox", async (req, res) => {
  const me = getActorUserId(req);
  const msgs = await prisma.directMessage.findMany({
    where: { OR: [{ fromUserId: me }, { toUserId: me }] }
  });
  const peerSet = new Set<string>();
  for (const m of msgs) {
    if (m.fromUserId === me) peerSet.add(m.toUserId);
    if (m.toUserId === me) peerSet.add(m.fromUserId);
  }
  const items = await Promise.all(
    [...peerSet].map(async (peerUserId) => {
      const thread = msgs.filter(
        (m) =>
          (m.fromUserId === me && m.toUserId === peerUserId) ||
          (m.fromUserId === peerUserId && m.toUserId === me)
      );
      const last = thread.reduce(
        (a, b) => (new Date(a.createdAt) > new Date(b.createdAt) ? a : b),
        thread[0]!
      );
      const peer = await prisma.user.findUnique({ where: { id: peerUserId } });
      return {
        peerUserId,
        peer: peer ? userToApi(peer) : null,
        lastMessage: last.text,
        lastAt: last.createdAt.toISOString()
      };
    })
  );
  items.sort((a, b) => new Date(b.lastAt).getTime() - new Date(a.lastAt).getTime());
  return res.json({ items });
});

apiRouter.get("/dm/:peerUserId/messages", async (req, res) => {
  const me = getActorUserId(req);
  const peer = req.params.peerUserId;
  const rows = await prisma.directMessage.findMany({
    where: {
      OR: [
        { fromUserId: me, toUserId: peer },
        { fromUserId: peer, toUserId: me }
      ]
    },
    orderBy: { createdAt: "asc" }
  });
  const items = rows.map((m) => ({
    id: m.id,
    fromUserId: m.fromUserId,
    toUserId: m.toUserId,
    text: m.text,
    createdAt: m.createdAt.toISOString()
  }));
  return res.json({ items });
});

apiRouter.post("/dm/:peerUserId/messages", async (req, res) => {
  const me = getActorUserId(req);
  const peer = req.params.peerUserId;
  const { text } = req.body ?? {};
  if (!text || String(text).trim().length === 0) {
    return res.status(400).json({ message: "text is required" });
  }
  const peerUser = await prisma.user.findUnique({ where: { id: peer } });
  if (!peerUser) return res.status(404).json({ message: "Peer user not found" });
  const msg = await prisma.directMessage.create({
    data: {
      fromUserId: me,
      toUserId: peer,
      text: String(text).slice(0, 2000)
    }
  });
  return res.status(201).json({
    id: msg.id,
    fromUserId: msg.fromUserId,
    toUserId: msg.toUserId,
    text: msg.text,
    createdAt: msg.createdAt.toISOString()
  });
});

apiRouter.get("/groups/:groupId/chat/messages", async (req, res) => {
  const rows = await prisma.chatMessage.findMany({
    where: { groupId: req.params.groupId },
    orderBy: { createdAt: "asc" }
  });
  const items = rows.map((m) => ({
    id: m.id,
    groupId: m.groupId,
    userId: m.userId,
    text: m.text,
    isPinned: m.isPinned,
    createdAt: m.createdAt.toISOString()
  }));
  return res.json({ items });
});

apiRouter.post("/groups/:groupId/chat/messages", async (req, res) => {
  const userId = getActorUserId(req);
  const { text } = req.body ?? {};
  if (!text || String(text).trim().length === 0) {
    return res.status(400).json({ message: "text is required" });
  }
  const item = await prisma.chatMessage.create({
    data: {
      groupId: req.params.groupId,
      userId,
      text: String(text),
      isPinned: false
    }
  });
  return res.status(201).json({
    id: item.id,
    groupId: item.groupId,
    userId: item.userId,
    text: item.text,
    isPinned: item.isPinned,
    createdAt: item.createdAt.toISOString()
  });
});

apiRouter.patch("/groups/:groupId/chat/messages/:messageId/pin", async (req, res) => {
  const actor = getActorUserId(req);
  const group = await prisma.group.findUnique({ where: { id: req.params.groupId } });
  if (!group) return res.status(404).json({ message: "Group not found" });
  if (group.hostUserId !== actor) return res.status(403).json({ message: "Forbidden" });
  const item = await prisma.chatMessage.updateMany({
    where: { id: req.params.messageId, groupId: req.params.groupId },
    data: { isPinned: true }
  });
  if (item.count === 0) return res.status(404).json({ message: "Message not found" });
  const m = await prisma.chatMessage.findFirst({
    where: { id: req.params.messageId, groupId: req.params.groupId }
  });
  if (!m) return res.status(404).json({ message: "Message not found" });
  return res.json({
    id: m.id,
    groupId: m.groupId,
    userId: m.userId,
    text: m.text,
    isPinned: m.isPinned,
    createdAt: m.createdAt.toISOString()
  });
});

apiRouter.get("/groups/:groupId/chat/polls", async (req, res) => {
  const rows = await prisma.chatPoll.findMany({ where: { groupId: req.params.groupId } });
  const items = rows.map((p) => ({
    id: p.id,
    groupId: p.groupId,
    question: p.question,
    options: p.options as string[],
    votes: p.votes as Record<string, number>,
    createdAt: p.createdAt.toISOString()
  }));
  return res.json({ items });
});

apiRouter.post("/groups/:groupId/chat/polls", async (req, res) => {
  const actor = getActorUserId(req);
  const group = await prisma.group.findUnique({ where: { id: req.params.groupId } });
  if (!group) return res.status(404).json({ message: "Group not found" });
  if (group.hostUserId !== actor) return res.status(403).json({ message: "Forbidden" });
  const { question, options } = req.body ?? {};
  if (!question || !Array.isArray(options) || options.length < 2) {
    return res.status(400).json({ message: "question and at least two options are required" });
  }
  const item = await prisma.chatPoll.create({
    data: {
      groupId: req.params.groupId,
      question: String(question),
      options: options.map((v: unknown) => String(v)),
      votes: {}
    }
  });
  return res.status(201).json({
    id: item.id,
    groupId: item.groupId,
    question: item.question,
    options: item.options as string[],
    votes: item.votes as Record<string, number>,
    createdAt: item.createdAt.toISOString()
  });
});

apiRouter.post("/groups/:groupId/chat/polls/:pollId/votes", async (req, res) => {
  const { optionIndex } = req.body ?? {};
  if (typeof optionIndex !== "number") return res.status(400).json({ message: "optionIndex is required" });
  const poll = await prisma.chatPoll.findFirst({
    where: { id: req.params.pollId, groupId: req.params.groupId }
  });
  if (!poll) return res.status(404).json({ message: "Poll not found" });
  const options = poll.options as string[];
  if (optionIndex < 0 || optionIndex >= options.length) {
    return res.status(400).json({ message: "Invalid optionIndex" });
  }
  const votes = { ...(poll.votes as Record<string, number>) };
  votes[String(optionIndex)] = (votes[String(optionIndex)] ?? 0) + 1;
  const updated = await prisma.chatPoll.update({
    where: { id: poll.id },
    data: { votes }
  });
  return res.json({
    id: updated.id,
    groupId: updated.groupId,
    question: updated.question,
    options: updated.options as string[],
    votes: updated.votes as Record<string, number>,
    createdAt: updated.createdAt.toISOString()
  });
});

apiRouter.post("/coaching/register", async (req, res) => {
  const userId = getActorUserId(req);
  const body = req.body ?? {};
  const bio = typeof body.bio === "string" ? body.bio.trim() : "";
  const hourlyRateWon = Number(body.hourlyRateWon);
  const preferredVenueIds = Array.isArray(body.preferredVenueIds)
    ? body.preferredVenueIds.map((v: unknown) => String(v))
    : [];
  if (bio.length < 1) return res.status(400).json({ message: "bio is required" });
  if (!Number.isFinite(hourlyRateWon) || hourlyRateWon < 0) {
    return res.status(400).json({ message: "hourlyRateWon must be a non-negative number" });
  }
  const existing = await prisma.coachProfile.findUnique({ where: { userId } });
  const data = {
    bio,
    hourlyRateWon,
    preferredVenueIds
  };
  const profile = existing
    ? await prisma.coachProfile.update({ where: { userId }, data })
    : await prisma.coachProfile.create({ data: { userId, ...data } });
  return res.status(existing ? 200 : 201).json({
    id: profile.id,
    userId: profile.userId,
    bio: profile.bio,
    hourlyRateWon: profile.hourlyRateWon,
    preferredVenueIds: profile.preferredVenueIds as string[],
    createdAt: profile.createdAt.toISOString()
  });
});

apiRouter.get("/coaching/coaches", async (_req, res) => {
  const rows = await prisma.coachProfile.findMany();
  const userIds = rows.map((c) => c.userId);
  const users = await prisma.user.findMany({ where: { id: { in: userIds } } });
  const byId = new Map(users.map((u) => [u.id, userToApi(u)]));
  const items = rows.map((c) => ({
    id: c.id,
    userId: c.userId,
    bio: c.bio,
    hourlyRateWon: c.hourlyRateWon,
    preferredVenueIds: c.preferredVenueIds as string[],
    createdAt: c.createdAt.toISOString(),
    user: byId.get(c.userId) ?? null
  }));
  return res.json({ items });
});

apiRouter.post("/coaching/bookings", async (req, res) => {
  const studentUserId = getActorUserId(req);
  const body = req.body ?? {};
  const coachUserId = typeof body.coachUserId === "string" ? body.coachUserId : "";
  const startsAt = typeof body.startsAt === "string" ? body.startsAt : "";
  const venueId =
    typeof body.venueId === "string" && body.venueId.length > 0 ? body.venueId : null;
  const note =
    typeof body.note === "string" && body.note.trim().length > 0 ? String(body.note).slice(0, 500) : null;
  if (!coachUserId || !startsAt) {
    return res.status(400).json({ message: "coachUserId and startsAt are required" });
  }
  if (studentUserId === coachUserId) {
    return res.status(400).json({ message: "Cannot book a lesson with yourself" });
  }
  const coach = await prisma.coachProfile.findUnique({ where: { userId: coachUserId } });
  if (!coach) return res.status(404).json({ message: "Coach profile not found" });
  const booking = await prisma.lessonBooking.create({
    data: {
      coachUserId,
      studentUserId,
      startsAt: new Date(startsAt),
      venueId,
      note,
      status: "pending"
    }
  });
  await pushInAppNotification(coachUserId, "lesson_booking_request", {
    bookingId: booking.id,
    studentUserId,
    startsAt: booking.startsAt.toISOString()
  });
  return res.status(201).json({
    id: booking.id,
    coachUserId: booking.coachUserId,
    studentUserId: booking.studentUserId,
    startsAt: booking.startsAt.toISOString(),
    venueId: booking.venueId,
    note: booking.note,
    status: booking.status,
    createdAt: booking.createdAt.toISOString()
  });
});

apiRouter.get("/coaching/bookings/me", async (req, res) => {
  const me = getActorUserId(req);
  const [asCoach, asStudent] = await Promise.all([
    prisma.lessonBooking.findMany({ where: { coachUserId: me } }),
    prisma.lessonBooking.findMany({ where: { studentUserId: me } })
  ]);
  const mapBooking = (b: (typeof asCoach)[0]) => ({
    id: b.id,
    coachUserId: b.coachUserId,
    studentUserId: b.studentUserId,
    startsAt: b.startsAt.toISOString(),
    venueId: b.venueId,
    note: b.note,
    status: b.status,
    createdAt: b.createdAt.toISOString()
  });
  return res.json({
    asCoach: asCoach.map(mapBooking),
    asStudent: asStudent.map(mapBooking)
  });
});

apiRouter.patch("/coaching/bookings/:bookingId", async (req, res) => {
  const me = getActorUserId(req);
  const booking = await prisma.lessonBooking.findUnique({ where: { id: req.params.bookingId } });
  if (!booking) return res.status(404).json({ message: "Booking not found" });
  const status = req.body?.status;
  if (booking.coachUserId === me) {
    if (status === "confirmed" || status === "cancelled") {
      const updated = await prisma.lessonBooking.update({
        where: { id: booking.id },
        data: { status }
      });
      if (status === "confirmed") {
        await pushInAppNotification(booking.studentUserId, "lesson_booking_confirmed", {
          bookingId: booking.id,
          coachUserId: booking.coachUserId,
          startsAt: updated.startsAt.toISOString()
        });
      }
      return res.json({
        id: updated.id,
        coachUserId: updated.coachUserId,
        studentUserId: updated.studentUserId,
        startsAt: updated.startsAt.toISOString(),
        venueId: updated.venueId,
        note: updated.note,
        status: updated.status,
        createdAt: updated.createdAt.toISOString()
      });
    }
  }
  if (booking.studentUserId === me && status === "cancelled" && booking.status === "pending") {
    const updated = await prisma.lessonBooking.update({
      where: { id: booking.id },
      data: { status: "cancelled" }
    });
    return res.json({
      id: updated.id,
      coachUserId: updated.coachUserId,
      studentUserId: updated.studentUserId,
      startsAt: updated.startsAt.toISOString(),
      venueId: updated.venueId,
      note: updated.note,
      status: updated.status,
      createdAt: updated.createdAt.toISOString()
    });
  }
  return res.status(403).json({ message: "Forbidden" });
});
