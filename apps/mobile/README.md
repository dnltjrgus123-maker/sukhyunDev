# Flutter 앱 구조 가이드

## 목표
- 구장 탐색 -> 모임 조회 -> 가입 신청 흐름을 3탭 이내로 제공
- 운영자 신청 승인/일정 관리 기능 제공

## 권장 구조
```text
lib/
  core/
    app_router.dart
    app_theme.dart
    env.dart
    network/
      api_client.dart
      auth_interceptor.dart
  features/
    auth/
      presentation/
      application/
      domain/
      infrastructure/
    venue/
    group/
    membership/
    event/
    notification/
    favorite/          # Phase 1.5
    lightning_match/   # Phase 1.5
    review/            # Phase 2
    chat/              # Phase 2
  shared/
    widgets/
    models/
    utils/
```

## 상태관리 규칙
- Provider 또는 Riverpod 중 하나만 선택해 일관되게 유지
- ViewModel/Notifier에서만 API 호출
- UI 레이어는 상태 렌더링과 사용자 입력 처리에 집중

## 라우트 우선순위
1. `/home`
2. `/venues`
3. `/venues/:id`
4. `/groups/:id`
5. `/my/memberships`
6. `/host/groups/:id/requests`
7. `/host/groups/:id/events`
