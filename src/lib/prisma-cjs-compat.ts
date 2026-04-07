/**
 * @prisma/client는 CJS이며, Prisma 버전에 따라 enum이 PascalCase 또는 snake_case로
 * 내보내질 수 있어 default import 후 두 이름 모두 시도합니다.
 */
import prismaModule from "@prisma/client";

function pickEnumRecord(pascal: string, snake: string): Record<string, string> {
  const m = prismaModule as Record<string, Record<string, string> | undefined>;
  const v = m[pascal] ?? m[snake];
  if (!v) {
    throw new Error(`@prisma/client: enum "${pascal}" / "${snake}" 를 찾을 수 없습니다. prisma generate를 실행하세요.`);
  }
  return v;
}

export const PrismaClient = prismaModule.PrismaClient;
export const Prisma = prismaModule.Prisma;
export const MembershipStatus = pickEnumRecord("MembershipStatus", "membership_status");
export const GroupStatus = pickEnumRecord("GroupStatus", "group_status");
export const SkillLevel = pickEnumRecord("SkillLevel", "skill_level");
export const UserRole = pickEnumRecord("UserRole", "user_role");
