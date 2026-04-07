import express from "express";
import { errorHandler } from "./middleware/error-handler.js";
import {
  InMemoryGroupRepository,
  InMemoryMembershipRepository
} from "./repositories/in-memory.repository.js";
import { createMembershipRouter } from "./routes/memberships.route.js";
import { seedGroups, seedMemberships } from "./seed/data.js";
import { MembershipService } from "./services/membership.service.js";
import { InMemoryNotificationService } from "./services/notification.service.js";

export function createApp() {
  const app = express();
  app.use(express.json());

  const groupRepo = new InMemoryGroupRepository(seedGroups);
  const membershipRepo = new InMemoryMembershipRepository(seedMemberships);
  const notificationService = new InMemoryNotificationService();
  const membershipService = new MembershipService(
    membershipRepo,
    groupRepo,
    notificationService
  );

  app.get("/health", (_req, res) => {
    res.json({ ok: true });
  });

  app.use("/api", createMembershipRouter(membershipService));

  app.get("/api/notifications", (_req, res) => {
    res.json({ items: notificationService.list() });
  });

  app.use(errorHandler);

  return app;
}
