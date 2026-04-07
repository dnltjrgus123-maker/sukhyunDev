import "dotenv/config";
import {
  GroupStatus,
  PrismaClient,
  SkillLevel,
  UserRole,
  type SkillLevelVal
} from "../src/lib/prisma-cjs-compat.js";
import { SEED_UUID } from "../src/constants/dev-seed-ids.js";

const prisma = new PrismaClient();

async function main() {
  const u = SEED_UUID.users;
  const v = SEED_UUID.venues;
  const g = SEED_UUID.groups;

  await prisma.user.upsert({
    where: { id: u.host1 },
    create: {
      id: u.host1,
      email: "host@example.com",
      nickname: "서울호스트",
      photoUrl: "https://picsum.photos/seed/u-host-1/256/256",
      skillLevel: SkillLevel.advanced,
      role: UserRole.host
    },
    update: {
      email: "host@example.com",
      nickname: "서울호스트",
      photoUrl: "https://picsum.photos/seed/u-host-1/256/256",
      skillLevel: SkillLevel.advanced,
      role: UserRole.host
    }
  });

  const members: Array<{
    id: string;
    email: string | null;
    nickname: string;
    photoUrl: string | null;
    skill: SkillLevelVal;
  }> = [
    {
      id: u.member1,
      email: "member@example.com",
      nickname: "경기멤버",
      photoUrl: "https://picsum.photos/seed/u-member-1/256/256",
      skill: SkillLevel.intermediate
    },
    {
      id: u.member2,
      email: null,
      nickname: "초급A",
      photoUrl: "https://picsum.photos/seed/u-member-2/256/256",
      skill: SkillLevel.beginner
    },
    {
      id: u.member3,
      email: null,
      nickname: "초급B",
      photoUrl: null,
      skill: SkillLevel.beginner
    },
    {
      id: u.member4,
      email: null,
      nickname: "중급플레이어",
      photoUrl: "https://picsum.photos/seed/u-member-4/256/256",
      skill: SkillLevel.intermediate
    },
    {
      id: u.member5,
      email: null,
      nickname: "고급김",
      photoUrl: "https://picsum.photos/seed/u-member-5/256/256",
      skill: SkillLevel.advanced
    },
    {
      id: u.member6,
      email: null,
      nickname: "중상급",
      photoUrl: "https://picsum.photos/seed/u-member-6/256/256",
      skill: SkillLevel.advanced
    }
  ];

  for (const m of members) {
    await prisma.user.upsert({
      where: { id: m.id },
      create: {
        id: m.id,
        email: m.email,
        nickname: m.nickname,
        photoUrl: m.photoUrl,
        skillLevel: m.skill,
        role: UserRole.member
      },
      update: {
        email: m.email,
        nickname: m.nickname,
        photoUrl: m.photoUrl,
        skillLevel: m.skill,
        role: UserRole.member
      }
    });
  }

  await prisma.venue.upsert({
    where: { id: v.v1 },
    create: {
      id: v.v1,
      name: "강남 배드민턴센터",
      address: "서울 강남구 테헤란로 1",
      latitude: 37.5012,
      longitude: 127.0396,
      courtCount: 8,
      amenities: { parking: true },
      ratingAvg: 4.6
    },
    update: {
      name: "강남 배드민턴센터",
      address: "서울 강남구 테헤란로 1",
      latitude: 37.5012,
      longitude: 127.0396,
      courtCount: 8,
      amenities: { parking: true },
      ratingAvg: 4.6
    }
  });

  await prisma.venue.upsert({
    where: { id: v.v2 },
    create: {
      id: v.v2,
      name: "수원 실내체육관",
      address: "경기 수원시 팔달구 2",
      latitude: 37.2636,
      longitude: 127.0286,
      courtCount: 6,
      amenities: { parking: false },
      ratingAvg: 4.2
    },
    update: {
      name: "수원 실내체육관",
      address: "경기 수원시 팔달구 2",
      latitude: 37.2636,
      longitude: 127.0286,
      courtCount: 6,
      amenities: { parking: false },
      ratingAvg: 4.2
    }
  });

  await prisma.group.upsert({
    where: { id: g.g1 },
    create: {
      id: g.g1,
      name: "강남 새벽콕",
      hostUserId: u.host1,
      homeVenueId: v.v1,
      photoUrl: "https://picsum.photos/seed/g-1/800/400",
      description: "평일 새벽 운동 모임",
      levelMin: SkillLevel.intermediate,
      levelMax: SkillLevel.advanced,
      maxMembers: 30,
      requiresApproval: true,
      status: GroupStatus.recruiting
    },
    update: {
      name: "강남 새벽콕",
      hostUserId: u.host1,
      homeVenueId: v.v1,
      photoUrl: "https://picsum.photos/seed/g-1/800/400",
      description: "평일 새벽 운동 모임",
      levelMin: SkillLevel.intermediate,
      levelMax: SkillLevel.advanced,
      maxMembers: 30,
      requiresApproval: true,
      status: GroupStatus.recruiting
    }
  });

  await prisma.coachProfile.upsert({
    where: { userId: u.host1 },
    create: {
      id: SEED_UUID.coachProfile.demo1,
      userId: u.host1,
      bio: "깔끔한 기본기·스텝 위주 초·중급 레슨합니다.",
      hourlyRateWon: 50_000,
      preferredVenueIds: [v.v1]
    },
    update: {
      bio: "깔끔한 기본기·스텝 위주 초·중급 레슨합니다.",
      hourlyRateWon: 50_000,
      preferredVenueIds: [v.v1]
    }
  });
}

main()
  .then(() => {
    console.log("Seed completed.");
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => {
    void prisma.$disconnect();
  });
