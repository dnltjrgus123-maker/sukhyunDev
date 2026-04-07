import { Prisma } from "@prisma/client";
import { MembershipStatus as Ms } from "@prisma/client";
import { prisma } from "../lib/prisma.js";
import type {
  GroupRepository,
  MembershipRecord,
  MembershipRepository,
  MembershipStatus,
  NotificationService
} from "../services/membership.service.js";

function toRecord(m: {
  id: string;
  userId: string;
  groupId: string;
  role: string;
  status: string;
  requestedAt: Date;
  decidedAt: Date | null;
  decidedBy: string | null;
}): MembershipRecord {
  return {
    id: m.id,
    userId: m.userId,
    groupId: m.groupId,
    role: m.role === "manager" ? "manager" : "member",
    status: m.status as MembershipStatus,
    requestedAt: m.requestedAt,
    decidedAt: m.decidedAt,
    decidedBy: m.decidedBy
  };
}

export class PrismaMembershipRepository implements MembershipRepository {
  async findById(membershipId: string): Promise<MembershipRecord | null> {
    const m = await prisma.membership.findUnique({ where: { id: membershipId } });
    return m ? toRecord(m) : null;
  }

  async countApprovedMembers(groupId: string): Promise<number> {
    return prisma.membership.count({ where: { groupId, status: Ms.approved } });
  }

  async updateDecision(input: {
    membershipId: string;
    nextStatus: Extract<MembershipStatus, "approved" | "rejected">;
    decidedBy: string;
    decidedAt: Date;
  }): Promise<MembershipRecord> {
    const updated = await prisma.membership.update({
      where: { id: input.membershipId },
      data: {
        status: input.nextStatus === "approved" ? Ms.approved : Ms.rejected,
        decidedBy: input.decidedBy,
        decidedAt: input.decidedAt
      }
    });
    return toRecord(updated);
  }

  async createApplied(input: { userId: string; groupId: string }): Promise<MembershipRecord> {
    try {
      const created = await prisma.membership.create({
        data: {
          userId: input.userId,
          groupId: input.groupId,
          status: Ms.applied,
          role: "member"
        }
      });
      return toRecord(created);
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === "P2002") {
        throw new Error("Already applied");
      }
      throw e;
    }
  }
}

export class PrismaGroupRepository implements GroupRepository {
  async findById(groupId: string) {
    const g = await prisma.group.findUnique({ where: { id: groupId } });
    if (!g) return null;
    return { id: g.id, hostUserId: g.hostUserId, maxMembers: g.maxMembers };
  }
}

export class PrismaMembershipNotificationService implements NotificationService {
  async publish(input: {
    userId: string;
    type: "membership_approved" | "membership_rejected";
    payload: Record<string, unknown>;
  }): Promise<void> {
    await prisma.notification.create({
      data: {
        userId: input.userId,
        type: input.type,
        payload: input.payload as Prisma.InputJsonValue
      }
    });
  }
}
