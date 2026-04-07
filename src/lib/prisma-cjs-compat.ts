/**
 * @prisma/client는 CJS이며, 버전에 따라 enum export 이름이 PascalCase 또는 snake_case입니다.
 * default import로 가져온 뒤, Prisma Client 타입과 맞는 리터럴 유니온으로 단언합니다.
 */
import prismaModule from "@prisma/client";

/** prisma/schema.prisma 의 MembershipStatus 값 (DB·클라이언트 공통) */
type MembershipStatusVal = "applied" | "approved" | "rejected" | "expired";
type SkillLevelVal = "beginner" | "intermediate" | "advanced";
type UserRoleVal = "member" | "host" | "admin";
type GroupStatusVal = "recruiting" | "closed";

type MembershipStatusObj = {
  readonly applied: MembershipStatusVal;
  readonly approved: MembershipStatusVal;
  readonly rejected: MembershipStatusVal;
  readonly expired: MembershipStatusVal;
};
type SkillLevelObj = {
  readonly beginner: SkillLevelVal;
  readonly intermediate: SkillLevelVal;
  readonly advanced: SkillLevelVal;
};
type UserRoleObj = {
  readonly member: UserRoleVal;
  readonly host: UserRoleVal;
  readonly admin: UserRoleVal;
};
type GroupStatusObj = {
  readonly recruiting: GroupStatusVal;
  readonly closed: GroupStatusVal;
};

function pickEnum<E>(pascal: string, snake: string): E {
  const m = prismaModule as unknown as Record<string, E | undefined>;
  const v = m[pascal] ?? m[snake];
  if (v === undefined) {
    throw new Error(
      `@prisma/client: enum "${pascal}" / "${snake}" 을 찾을 수 없습니다. npx prisma generate 후 다시 빌드하세요.`
    );
  }
  return v;
}

export const PrismaClient = prismaModule.PrismaClient;
export const Prisma = prismaModule.Prisma;

export const MembershipStatus = pickEnum<MembershipStatusObj>("MembershipStatus", "membership_status");
export const GroupStatus = pickEnum<GroupStatusObj>("GroupStatus", "group_status");
export const SkillLevel = pickEnum<SkillLevelObj>("SkillLevel", "skill_level");
export const UserRole = pickEnum<UserRoleObj>("UserRole", "user_role");

export type { SkillLevelVal };
