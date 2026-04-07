# OpenAPI/DB 적용 가이드

이 문서는 현재 산출물(`docs/api/openapi.yaml`, `prisma/schema.prisma`, `db/schema.sql`)을 실제 개발 흐름에 연결하기 위한 최소 실행 가이드다.

## 1) 설치

```bash
npm install
```

## 2) OpenAPI 타입 생성

```bash
npm run openapi:types
```

- 생성 파일: `src/generated/api-types.ts`
- 목적: 프론트/백엔드 DTO 타입을 스펙 기준으로 동기화

## 3) OpenAPI 목 서버 실행

```bash
npm run openapi:mock
```

- 기본 URL: `http://localhost:4010`
- 목적: 백엔드 구현 전 화면/흐름 검증

## 4) Prisma 기반 DB 초기화

`.env`에 `DATABASE_URL`을 설정한 뒤 실행:

```bash
npm run db:migrate:dev
npm run db:generate
```

## 5) SQL 직접 적용(선택)

Prisma 마이그레이션 대신 SQL 초안을 직접 반영하려면:

```bash
npm run db:seed:sql
```

## 6) 다음 구현 우선순위

1. `MembershipService`를 API 핸들러에 연결해 가입 승인/거절 상태 전이 완성
2. `groups/{groupId}/memberships` 및 `decision` 엔드포인트 구현
3. 알림 생성(`membership_approved`, `membership_rejected`) 저장/조회 구현
