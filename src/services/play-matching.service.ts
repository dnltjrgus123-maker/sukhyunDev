import type { SkillLevel } from "../data/store.js";

export type MatchingMode = "random" | "balanced";

export interface CourtAssignment {
  courtIndex: number;
  teamA: [string, string];
  teamB: [string, string];
}

export function skillScore(level: SkillLevel): number {
  switch (level) {
    case "beginner":
      return 1;
    case "intermediate":
      return 2;
    case "advanced":
      return 3;
  }
}

export function skillRankInRange(level: SkillLevel, min: SkillLevel, max: SkillLevel): boolean {
  const r = skillScore(level);
  return r >= skillScore(min) && r <= skillScore(max);
}

/** 라운드마다 참가 순서를 순환시켜 파트너가 바뀌도록 함 */
export function rotateParticipantOrder(userIds: string[], roundNumber: number): string[] {
  if (userIds.length === 0) return [];
  const shift = ((roundNumber - 1) * 2) % userIds.length;
  return [...userIds.slice(shift), ...userIds.slice(0, shift)];
}

function shuffleIds(ids: string[], seed: number): string[] {
  const a = [...ids];
  let s = seed >>> 0;
  for (let i = a.length - 1; i > 0; i--) {
    s = (s * 1664525 + 1013904223) >>> 0;
    const j = s % (i + 1);
    const t = a[i];
    a[i] = a[j]!;
    a[j] = t!;
  }
  return a;
}

/**
 * 복식 코트 배정. 인원은 courtCount*4명까지만 사용(나머지는 이번 라운드 휴식).
 * random: 순서 셔플 후 4명씩 [0,1] vs [2,3]
 * balanced: 코트별 4명을 실력 순 정렬 후 [약,강] vs [중,중] 스네이크
 */
export function buildDoublesRound(
  participantIds: string[],
  getSkill: (userId: string) => SkillLevel,
  courtCount: number,
  mode: MatchingMode,
  roundNumber: number
): CourtAssignment[] {
  const rotated = rotateParticipantOrder(participantIds, roundNumber);
  const maxPlayers = courtCount * 4;
  let ordered = rotated.slice(0, Math.min(rotated.length, maxPlayers));
  const usable = ordered.length - (ordered.length % 4);
  ordered = ordered.slice(0, usable);

  if (ordered.length < 4) return [];

  let working = [...ordered];
  if (mode === "random") {
    working = shuffleIds(working, roundNumber * 9973 + participantIds.length);
  }

  const courts: CourtAssignment[] = [];
  for (let c = 0; c < working.length / 4; c++) {
    const chunk = working.slice(c * 4, c * 4 + 4);
    if (chunk.length < 4) break;
    if (mode === "balanced") {
      const sorted = [...chunk].sort((a, b) => skillScore(getSkill(a)) - skillScore(getSkill(b)));
      courts.push({
        courtIndex: c,
        teamA: [sorted[0]!, sorted[3]!],
        teamB: [sorted[1]!, sorted[2]!]
      });
    } else {
      courts.push({
        courtIndex: c,
        teamA: [chunk[0]!, chunk[1]!],
        teamB: [chunk[2]!, chunk[3]!]
      });
    }
  }
  return courts;
}
