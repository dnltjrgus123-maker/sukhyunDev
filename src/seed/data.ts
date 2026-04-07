import type { GroupRecord, MembershipRecord } from "../services/membership.service.js";

export const seedGroups: GroupRecord[] = [
  {
    id: "group-seoul-morning",
    hostUserId: "host-1",
    maxMembers: 12
  }
];

export const seedMemberships: MembershipRecord[] = [
  {
    id: "membership-1",
    userId: "user-101",
    groupId: "group-seoul-morning",
    role: "member",
    status: "applied",
    requestedAt: new Date(),
    decidedAt: null,
    decidedBy: null
  }
];
