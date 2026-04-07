# Node.js API 구조 가이드

## 목표
- Flutter 앱에서 필요한 MVP API를 안정적으로 제공
- 소셜 인증, 권한, 상태 전이 규칙을 서버에서 강제

## 권장 모듈 구조 (NestJS 기준)
```text
src/
  main.ts
  app.module.ts
  common/
    guards/
    decorators/
    filters/
  infra/
    prisma/
      prisma.service.ts
    auth/
      jwt.service.ts
  modules/
    auth/
    users/
    venues/
    groups/
    memberships/
    events/
    notifications/
    favorites/          # Phase 1.5
    lightning-matches/  # Phase 1.5
    reviews/            # Phase 2
```

## 도메인 정책
- 모임 생성 시 `requiresApproval` 설정(자동 승인/운영자 승인)
- 모임 공개 범위는 MVP에서 `is_public = true` 고정
- 정원 초과 상태에서는 승인 불가
- 신청 대기(`applied`) 장기 미응답 건은 만료(`expired`) 처리

## 보안/인가
- 소셜 로그인 후 앱용 Access/Refresh 토큰 발급
- 역할 기반 인가: member / host / admin
- 민감 작업(계정 병합, 소셜 연결 해제)은 최근 재인증 필요
