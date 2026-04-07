export type MembershipStatus = "applied" | "approved" | "rejected" | "expired";

export interface MembershipRecord {
  id: string;
  userId: string;
  groupId: string;
  role: "member" | "manager";
  status: MembershipStatus;
  requestedAt: Date;
  decidedAt: Date | null;
  decidedBy: string | null;
}

export interface GroupRecord {
  id: string;
  hostUserId: string;
  maxMembers: number;
}

export interface MembershipRepository {
  findById(membershipId: string): Promise<MembershipRecord | null>;
  countApprovedMembers(groupId: string): Promise<number>;
  updateDecision(input: {
    membershipId: string;
    nextStatus: Extract<MembershipStatus, "approved" | "rejected">;
    decidedBy: string;
    decidedAt: Date;
  }): Promise<MembershipRecord>;
  createApplied(input: { userId: string; groupId: string }): Promise<MembershipRecord>;
}

export interface GroupRepository {
  findById(groupId: string): Promise<GroupRecord | null>;
}

export interface NotificationService {
  publish(input: {
    userId: string;
    type: "membership_approved" | "membership_rejected";
    payload: Record<string, unknown>;
  }): Promise<void>;
}

export class DomainError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "DomainError";
  }
}

export class MembershipService {
  constructor(
    private readonly memberships: MembershipRepository,
    private readonly groups: GroupRepository,
    private readonly notifications: NotificationService
  ) {}

  async decideApplication(input: {
    membershipId: string;
    actorUserId: string;
    decision: "approve" | "reject";
  }): Promise<MembershipRecord> {
    const membership = await this.memberships.findById(input.membershipId);
    if (!membership) throw new DomainError("Membership not found.");
    if (membership.status !== "applied") {
      throw new DomainError("Only applied membership can be decided.");
    }

    const group = await this.groups.findById(membership.groupId);
    if (!group) throw new DomainError("Group not found.");
    if (group.hostUserId !== input.actorUserId) {
      throw new DomainError("Only host can decide application.");
    }

    if (input.decision === "approve") {
      const approvedCount = await this.memberships.countApprovedMembers(group.id);
      if (approvedCount >= group.maxMembers) {
        throw new DomainError("Group capacity is full.");
      }
    }

    const nextStatus = input.decision === "approve" ? "approved" : "rejected";
    const updated = await this.memberships.updateDecision({
      membershipId: membership.id,
      nextStatus,
      decidedBy: input.actorUserId,
      decidedAt: new Date()
    });

    await this.notifications.publish({
      userId: membership.userId,
      type: nextStatus === "approved" ? "membership_approved" : "membership_rejected",
      payload: {
        groupId: membership.groupId,
        membershipId: membership.id
      }
    });

    return updated;
  }
}
