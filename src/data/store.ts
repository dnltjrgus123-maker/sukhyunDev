import type { MembershipStatus } from "../services/membership.service.js";

export type SkillLevel = "beginner" | "intermediate" | "advanced";
export type SocialProvider = "kakao" | "naver" | "google";
export type NotificationType =
  | "membership_approved"
  | "membership_rejected"
  | "membership_expired"
  | "event_updated"
  | "play_session_start"
  | "play_session_spot_open"
  | "play_session_promoted_from_waitlist"
  | "lesson_booking_confirmed"
  | "lesson_booking_request";

export interface User {
  id: string;
  email: string | null;
  nickname: string;
  /** 프로필 사진 — HTTPS URL 또는 null */
  photoUrl: string | null;
  skillLevel: SkillLevel;
  role: "member" | "host" | "admin";
}

export interface SocialAccount {
  id: string;
  userId: string;
  provider: SocialProvider;
  providerUserId: string;
  email: string | null;
  emailVerified: boolean;
  linkedAt: string;
}

export interface Venue {
  id: string;
  name: string;
  address: string;
  courtCount: number;
  parking: boolean;
  ratingAvg: number;
  /** 지도 / 근처 검색용 (WGS84) */
  lat: number;
  lng: number;
}

export interface Group {
  id: string;
  name: string;
  hostUserId: string;
  homeVenueId: string;
  /** 모임 대표 프로필·커버 이미지 URL */
  photoUrl: string | null;
  levelMin: SkillLevel;
  levelMax: SkillLevel;
  maxMembers: number;
  memberCount: number;
  status: "recruiting" | "closed";
  requiresApproval: boolean;
  description: string;
}

export interface Membership {
  id: string;
  userId: string;
  groupId: string;
  role: "member" | "manager";
  status: MembershipStatus;
  requestedAt: Date;
  decidedAt: Date | null;
  decidedBy: string | null;
}

export interface AppNotification {
  id: string;
  userId: string;
  type: NotificationType;
  payload: Record<string, unknown>;
  readAt: string | null;
  createdAt: string;
}

export interface Favorite {
  id: string;
  userId: string;
  targetType: "venue" | "group" | "user";
  targetId: string;
  createdAt: string;
}

export interface LightningMatch {
  id: string;
  hostUserId: string;
  venueId: string;
  startAt: string;
  endAt: string;
  capacity: number;
  level: SkillLevel;
  status: "open" | "full" | "closed";
  note: string | null;
}

export interface Review {
  id: string;
  authorUserId: string;
  targetType: "venue" | "group";
  targetId: string;
  rating: number;
  comment: string | null;
  /** 피드용 이미지 URL (선택) */
  imageUrl: string | null;
  createdAt: string;
}

export interface UserFollow {
  id: string;
  followerId: string;
  followeeId: string;
  createdAt: string;
}

export interface DirectMessage {
  id: string;
  fromUserId: string;
  toUserId: string;
  text: string;
  createdAt: string;
}

export interface CoachProfile {
  id: string;
  userId: string;
  bio: string;
  /** 원 단위 시범 가격 */
  hourlyRateWon: number;
  /** 주 활동 구장 ID 목록 */
  preferredVenueIds: string[];
  createdAt: string;
}

export interface LessonBooking {
  id: string;
  coachUserId: string;
  studentUserId: string;
  startsAt: string;
  venueId: string | null;
  note: string | null;
  status: "pending" | "confirmed" | "cancelled";
  createdAt: string;
}

export interface ChatMessage {
  id: string;
  groupId: string;
  userId: string;
  text: string;
  isPinned: boolean;
  createdAt: string;
}

export interface ChatPoll {
  id: string;
  groupId: string;
  question: string;
  options: string[];
  votes: Record<string, number>;
  createdAt: string;
}

export type PlayMatchingMode = "random" | "balanced";

export interface PlayCourtAssignment {
  courtIndex: number;
  teamA: [string, string];
  teamB: [string, string];
}

export interface PlayRoundRecord {
  round: number;
  mode: PlayMatchingMode;
  courts: PlayCourtAssignment[];
  createdAt: string;
}

/** 모임 내 단일 운동/게임 세션 — 일시·장소·코트·실력 필터·정원·대기열·매칭 라운드 */
export interface PlaySession {
  id: string;
  groupId: string;
  hostUserId: string;
  name: string;
  venueId: string;
  startsAt: string;
  endsAt: string;
  courtCount: number;
  levelMin: SkillLevel;
  levelMax: SkillLevel;
  maxParticipants: number;
  participantIds: string[];
  waitlistIds: string[];
  defaultMatchingMode: PlayMatchingMode;
  currentRound: number;
  rounds: PlayRoundRecord[];
}

export interface AppStore {
  users: User[];
  socialAccounts: SocialAccount[];
  venues: Venue[];
  groups: Group[];
  memberships: Membership[];
  notifications: AppNotification[];
  favorites: Favorite[];
  lightningMatches: LightningMatch[];
  reviews: Review[];
  chatMessages: ChatMessage[];
  chatPolls: ChatPoll[];
  playSessions: PlaySession[];
  follows: UserFollow[];
  dmMessages: DirectMessage[];
  coachProfiles: CoachProfile[];
  lessonBookings: LessonBooking[];
}
