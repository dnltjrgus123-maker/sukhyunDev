import type {
  GroupRecord,
  GroupRepository,
  MembershipRecord,
  MembershipRepository,
  MembershipStatus
} from "../services/membership.service.js";
import { nextId } from "../utils/id.js";

export class InMemoryGroupRepository implements GroupRepository {
  constructor(private readonly groups: GroupRecord[]) {}

  async findById(groupId: string): Promise<GroupRecord | null> {
    return this.groups.find((group) => group.id === groupId) ?? null;
  }
}

export class InMemoryMembershipRepository implements MembershipRepository {
  constructor(private readonly memberships: MembershipRecord[]) {}

  async findById(membershipId: string): Promise<MembershipRecord | null> {
    return this.memberships.find((membership) => membership.id === membershipId) ?? null;
  }

  async countApprovedMembers(groupId: string): Promise<number> {
    return this.memberships.filter(
      (membership) => membership.groupId === groupId && membership.status === "approved"
    ).length;
  }

  async updateDecision(input: {
    membershipId: string;
    nextStatus: "approved" | "rejected";
    decidedBy: string;
    decidedAt: Date;
  }): Promise<MembershipRecord> {
    const membership = this.memberships.find((item) => item.id === input.membershipId);
    if (!membership) {
      throw new Error("Membership not found while updating decision.");
    }
    membership.status = input.nextStatus;
    membership.decidedBy = input.decidedBy;
    membership.decidedAt = input.decidedAt;
    return membership;
  }

  async createApplied(input: { userId: string; groupId: string }): Promise<MembershipRecord> {
    const exists = this.memberships.find((m) => m.userId === input.userId && m.groupId === input.groupId);
    if (exists) throw new Error("Already applied");
    const record: MembershipRecord = {
      id: nextId("m"),
      userId: input.userId,
      groupId: input.groupId,
      role: "member",
      status: "applied" as MembershipStatus,
      requestedAt: new Date(),
      decidedAt: null,
      decidedBy: null
    };
    this.memberships.push(record);
    return record;
  }
}
