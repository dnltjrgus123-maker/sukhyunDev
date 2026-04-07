/**
 * @prisma/client는 CJS라 Node ESM 환경에서 named import가 실패할 수 있습니다.
 * default import로 묶어 런타임 값만 재export 합니다.
 */
import prismaModule from "@prisma/client";

export const PrismaClient = prismaModule.PrismaClient;
export const Prisma = prismaModule.Prisma;
export const MembershipStatus = prismaModule.MembershipStatus;
