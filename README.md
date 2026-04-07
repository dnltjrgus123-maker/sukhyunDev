# 배드민턴 모임 앱 (Flutter + Node.js)

본 저장소는 배드민턴 모임 앱 MVP 구현을 위한 기준 구조를 담는다.

## 기술 스택
- 앱: Flutter
- 백엔드: Node.js (NestJS 권장)
- DB: PostgreSQL + Prisma
- 문서: OpenAPI (`docs/api/openapi.yaml`)

## 핵심 도메인
- 구장(`Venue`) 중심 모임 탐색
- 모임(`Group`) 가입 신청/승인(`Membership`)
- 정모 일정(`Event`) 및 알림(`Notification`)
- 소셜 로그인/연동(`SocialAccount`)

## 디렉토리
- `docs/mvp-execution-spec.md`: MVP 실행 명세
- `docs/api/openapi.yaml`: API 계약
- `db/schema.sql`: SQL 스키마
- `prisma/schema.prisma`: Prisma 모델
- `docs/product/user-flows.md`: 사용자/운영자 흐름
- `docs/product/phase-backlog.md`: Phase 1~3 실행 백로그
- `apps/mobile/README.md`: Flutter 앱 구조 가이드
- `apps/api/README.md`: Node.js 백엔드 구조 가이드

## 우선 구현 순서
1. 소셜 인증(카카오/네이버/구글) + JWT 세션
2. 구장 목록/상세 + 해당 구장 모임 목록
3. 모임 가입 신청/승인
4. 운영자 정모 일정 관리 + 알림
5. MVP 직후: 번개 매칭/즐겨찾기/알림 고도화

## 실행 메모
- 백엔드 실행: `npm run dev`
- Flutter 실행 예시:
  - Dev: `flutter run --dart-define=APP_FLAVOR=dev --dart-define=API_BASE_URL=http://localhost:4000`
  - Stage: `flutter run --dart-define=APP_FLAVOR=stage --dart-define=API_BASE_URL=https://stage-api.example.com`
  - Prod: `flutter run --dart-define=APP_FLAVOR=prod --dart-define=API_BASE_URL=https://api.example.com`

## 추가된 API 스켈레톤
- OAuth 준비: `GET /auth/social/:provider/start`, `POST /auth/social/:provider/callback`
- 채팅 고도화 기반:
  - `GET/POST /groups/:groupId/chat/messages`
  - `PATCH /groups/:groupId/chat/messages/:messageId/pin`
  - `GET/POST /groups/:groupId/chat/polls`
  - `POST /groups/:groupId/chat/polls/:pollId/votes`
