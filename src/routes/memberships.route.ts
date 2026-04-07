import { Router } from "express";
import type { MembershipService } from "../services/membership.service.js";

interface DecideRequestBody {
  actorUserId?: string;
  decision?: "approve" | "reject";
}

export function createMembershipRouter(service: MembershipService): Router {
  const router = Router();

  router.patch(
    "/groups/:groupId/memberships/:membershipId/decision",
    async (req, res, next) => {
      try {
        const { membershipId } = req.params;
        const body = req.body as DecideRequestBody;

        if (!body.actorUserId || !body.decision) {
          res.status(400).json({
            message: "actorUserId and decision are required."
          });
          return;
        }

        const membership = await service.decideApplication({
          membershipId,
          actorUserId: body.actorUserId,
          decision: body.decision
        });

        res.json(membership);
      } catch (error) {
        next(error);
      }
    }
  );

  return router;
}
