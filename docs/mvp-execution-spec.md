# 배드민턴 모임 앱 MVP 실행 명세

이 문서는 기능 설계안을 실제 실행 가능한 범위로 고정하기 위한 산출물이다.  
원본 설계 문서는 참조만 하며, 이 문서에서 MVP 범위/데이터 모델/화면 흐름/로드맵을 최종 확정한다.

## 1. MVP 핵심 기능 범위 확정 (define-mvp-scope)

### 1.1 포함 범위 (In Scope)

#### A. 구장 목록/상세
- 지도 + 리스트 동시 제공
- 필터: 지역, 코트 수, 운영시간, 주차 가능 여부
- 정렬: 거리순, 평점순
- 구장 상세: 주소, 시설 정보, 사진, 평점 요약
- 구장 상세 내 "이 구장을 사용하는 모임" 탭 제공

#### B. 모임 조회/상세
- 모임 목록 검색 및 필터
- 모임 카드 필수 정보: 모임명, 레벨 범위, 정기 일정, 모집 상태, 현재 인원/정원
- 모임 상세: 소개, 참여 조건, 정모 일정(다가오는 일정 기준)

#### C. 모임 가입 신청/승인
- 사용자는 모임 상세에서 가입 신청 가능
- 가입 방식은 모임 단위로 설정:
  - 자동 승인
  - 운영자 승인
- 신청 상태: 신청됨, 승인됨, 거절됨, 만료됨
- 운영자는 신청 목록에서 승인/거절 가능

#### D. 기본 알림
- 가입 승인/거절 즉시 알림
- 신청 만료 알림
- 정모 일정 변경 시 참여자 알림

### 1.2 제외 범위 (Out of Scope)
- 모임 채팅
- 신고/패널티/평판 점수 자동화
- 결제/정산/환불
- 추천 알고리즘 고도화
- QR 체크인 및 출석 자동화
- 고급 통계 대시보드

### 1.3 MVP 성공 기준 (출시 최소 기준)
- 사용자는 3탭 이내로 구장 탐색 -> 모임 상세 -> 가입 신청까지 완료 가능
- 운영자는 승인 대기 신청을 1분 이내 처리 가능
- 신청 상태 변경 알림이 5초 내 반영(앱 내 알림 기준)

## 2. 핵심 데이터 모델 확정 (model-domain-entities)

### 2.1 엔터티 정의

#### User
- id (UUID, PK)
- email (UNIQUE, NOT NULL)
- nickname (NOT NULL)
- skillLevel (ENUM: beginner/intermediate/advanced)
- preferredArea (VARCHAR, NULL)
- preferredTimeSlots (JSON, NULL)
- role (ENUM: guest/member/host/admin, default member)
- createdAt, updatedAt

#### Venue
- id (UUID, PK)
- name (NOT NULL)
- address (NOT NULL)
- latitude, longitude (DECIMAL)
- courtCount (INT)
- openHours (JSON)
- amenities (JSON: parking/shower/racket-rental 등)
- ratingAvg (DECIMAL, default 0)
- reviewCount (INT, default 0)
- createdAt, updatedAt

#### Group
- id (UUID, PK)
- name (NOT NULL)
- hostUserId (FK -> User.id, NOT NULL)
- homeVenueId (FK -> Venue.id, NULL)
- description (TEXT)
- levelMin, levelMax (ENUM)
- maxMembers (INT, NOT NULL)
- requiresApproval (BOOLEAN, default true)
- membershipPolicy (JSON)
- status (ENUM: recruiting/closed, default recruiting)
- createdAt, updatedAt

#### Event
- id (UUID, PK)
- groupId (FK -> Group.id, NOT NULL)
- venueId (FK -> Venue.id, NOT NULL)
- title (VARCHAR, NOT NULL)
- startAt, endAt (DATETIME, NOT NULL)
- fee (INT, default 0)
- capacity (INT, NOT NULL)
- createdBy (FK -> User.id, NOT NULL)
- createdAt, updatedAt

#### Membership
- id (UUID, PK)
- userId (FK -> User.id, NOT NULL)
- groupId (FK -> Group.id, NOT NULL)
- role (ENUM: member/manager, default member)
- status (ENUM: applied/approved/rejected/expired, NOT NULL)
- requestedAt (DATETIME, NOT NULL)
- decidedAt (DATETIME, NULL)
- decidedBy (FK -> User.id, NULL)
- UNIQUE(userId, groupId)

### 2.2 핵심 관계
- User 1:N Group (host)
- Group 1:N Event
- Group N:M User via Membership
- Venue 1:N Event
- Venue 1:N Group(homeVenueId 기준, optional)

### 2.3 비즈니스 규칙
- 정원 초과 시 Membership 상태를 approved로 변경 불가
- already approved 상태에서 중복 신청 불가 (UNIQUE + 상태 검증)
- Event 생성 시 그룹 상태가 recruiting 또는 closed라도 생성 가능(운영 정책에 따름)
- 신청 후 N시간(기본 24시간) 무응답이면 expired 처리

## 3. 사용자/운영자 화면 흐름 및 권한 상세 (design-user-flows)

### 3.1 사용자 흐름 (Member)
1. 홈 진입 -> 추천 모임/인기 구장 노출
2. 구장 탭 -> 필터/정렬로 구장 탐색
3. 구장 상세 -> 해당 구장 모임 목록 확인
4. 모임 상세 -> 조건 확인 후 가입 신청
5. 내 페이지 -> 신청 현황/알림 확인

### 3.2 운영자 흐름 (Host)
1. 내 모임 -> 운영 중 모임 선택
2. 신청 관리 -> 신청자 목록 조회
3. 신청 승인/거절 처리
4. 정모 일정 생성/수정
5. 일정 변경 시 참여자에게 공지/알림 발송

### 3.3 화면 목록 (Phase 1 기준)
- 홈
- 구장 목록(지도/리스트)
- 구장 상세(시설/리뷰요약/모임탭)
- 모임 목록
- 모임 상세
- 가입 신청 상태 화면(또는 섹션)
- 운영자 신청 관리 화면
- 정모 일정 관리 화면
- 마이페이지(내 모임/신청 현황/알림)

### 3.4 권한 정책 상세

#### Guest
- 가능: 구장/모임 목록 및 상세 조회
- 제한: 가입 신청, 리뷰 작성, 운영 기능

#### Member
- 가능: 가입 신청, 신청 취소(승인 전), 알림 확인
- 제한: 운영자 전용 신청 처리/일정 관리

#### Host
- 가능: 본인 모임의 신청 승인/거절, 일정 관리, 모임 정보 수정
- 제한: 타 모임 관리, 관리자 제재 기능

#### Admin
- 가능: 신고 처리, 제재, 전체 데이터 운영
- 제한: 없음(정책상 최고 권한)

### 3.5 예외 플로우
- 승인 대기 중 재신청 시: 기존 신청 상태 안내 후 차단
- 모집 마감 모임 신청 시: 신청 불가 메시지
- 정원 가득 찬 경우: 대기 기능 미포함(Phase 2 후보), 신청 차단

## 4. Phase 1~3 로드맵 및 우선순위 백로그 (prioritize-phase-roadmap)

## 4.1 Phase 일정
- Phase 1 (4~6주): MVP 출시
- Phase 2 (3~4주): 참여 편의/신뢰 기능
- Phase 3 (3~5주): 수익화/고급 운영

### 4.2 우선순위 백로그 (MoSCoW)

#### Must (Phase 1)
- 소셜 회원가입/로그인(카카오/네이버/구글) + 기본 프로필
- 구장 목록/필터/상세
- 구장 기반 모임 조회
- 모임 상세/가입 신청
- 승인/거절 워크플로우
- 알림센터(신청 상태/일정 변경)

#### Should (Phase 1.5)
- 번개 매칭(빠른 인원 모집/참가)
- 알림 고도화(개인화 리마인드, 중요 공지 우선)
- 즐겨찾기(구장/모임 저장)

#### Should (Phase 2)
- 후기/평점
- 채팅 고도화(공지 고정, 투표, 읽음 상태, 모더레이션)
- 신고/패널티 기본 정책
- 추천(레벨/거리/시간대 기반)

#### Could (Phase 3)
- 참가비 결제/환불
- 운영진 정산 리포트
- 혼잡도 히트맵/랭킹

#### Won't (현재 릴리즈)
- 전국 동시 확장(초기에는 핵심 지역 집중)
- 고도화된 평판 자동 산식

### 4.3 실행 순서 (개발 백로그)
1. 소셜 인증/권한 기반 구축(카카오/네이버/구글)
2. Venue + Group 조회 API 및 리스트 UI
3. Membership 신청/승인 상태 전이 구현
4. Event 조회/관리 + 일정 변경 알림
5. 알림센터 통합 및 QA
6. Phase 1.5: 번개 매칭/즐겨찾기/알림 고도화
7. Phase 2: 후기/평점 + 채팅 고도화

### 4.4 마일스톤 산출물
- M1: 구장/모임 탐색 가능 (읽기 중심)
- M2: 가입 신청/승인 end-to-end 동작
- M3: 운영자 일정 관리 + 알림 안정화
- M4: MVP 베타 릴리즈 및 지표 수집 시작
