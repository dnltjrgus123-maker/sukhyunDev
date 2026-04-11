import "dart:convert";

import "package:http/http.dart" as http;

import "../models/app_models.dart";
import "api_exception.dart";

class ApiClient {
  ApiClient({
    required this.baseUrl,
    this.actorUserId = "00000000-0000-4000-8000-000000000002",
    this.getAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String actorUserId;
  /// Supabase `session.accessToken` 등 — 있으면 서버가 `sub`로 액터를 확정합니다.
  final Future<String?> Function()? getAccessToken;
  final http.Client _client;

  Future<Map<String, String>> getHeaders() async => _headers();

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      "Content-Type": "application/json",
      "x-user-id": actorUserId,
    };
    final token = await getAccessToken?.call();
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }
    return headers;
  }

  Future<Map<String, String>> _publicJsonHeaders() async => <String, String>{
        "Content-Type": "application/json",
      };

  /// 서버 프록시 카카오 로그인(account_email 미사용) — [GET /auth/kakao/authorize-url]
  Future<String> getKakaoAuthorizeUrl() async {
    final response = await _client.get(
      _uri("/auth/kakao/authorize-url"),
      headers: await _publicJsonHeaders(),
    );
    _ensureSuccess(response, "카카오 로그인 URL을 가져오지 못했습니다");
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body["url"] as String;
  }

  Future<SocialAuthResult> claimKakaoTicket(String ticket) async {
    final response = await _client.post(
      _uri("/auth/kakao/claim"),
      headers: await _publicJsonHeaders(),
      body: jsonEncode({"ticket": ticket}),
    );
    _ensureSuccess(response, "카카오 로그인 완료 처리 실패");
    return SocialAuthResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse("$baseUrl$path").replace(queryParameters: query);
  }

  void _ensureSuccess(http.Response response, String message) {
    if (response.statusCode >= 400) {
      throw ApiException(
        statusCode: response.statusCode,
        message: message,
        body: response.body,
      );
    }
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await _client.get(_uri("/users/me"), headers: await _headers());
    _ensureSuccess(response, "프로필을 불러오지 못했습니다");
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// OAuth/가입 직후 Supabase `sub`와 동일한 `users` 행을 서버에 맞춥니다.
  Future<Map<String, dynamic>> syncProfile({String? nickname, String? photoUrl}) async {
    final body = <String, dynamic>{};
    if (nickname != null) body["nickname"] = nickname;
    if (photoUrl != null) body["photoUrl"] = photoUrl;
    final response = await _client.post(
      _uri("/users/sync"),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    _ensureSuccess(response, "프로필 동기화 실패");
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// 모임 생성 (호스트는 Bearer 토큰의 `sub`).
  Future<Map<String, dynamic>> createGroup({
    required String name,
    String? homeVenueId,
    String? description,
    String levelMin = "beginner",
    String levelMax = "advanced",
    int maxMembers = 20,
    bool requiresApproval = true,
    String? photoUrl,
  }) async {
    final response = await _client.post(
      _uri("/groups"),
      headers: await _headers(),
      body: jsonEncode({
        "name": name,
        if (homeVenueId != null && homeVenueId.isNotEmpty) "homeVenueId": homeVenueId,
        "description": description ?? "",
        "levelMin": levelMin,
        "levelMax": levelMax,
        "maxMembers": maxMembers,
        "requiresApproval": requiresApproval,
        if (photoUrl != null && photoUrl.isNotEmpty) "photoUrl": photoUrl,
      }),
    );
    _ensureSuccess(response, "모임 만들기 실패");
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// [patch] 예: `{"nickname":"새닉"}` , `{"photoUrl":"https://…"}` , 사진 제거 시 `"photoUrl":""`
  Future<Map<String, dynamic>> patchCurrentUserProfile(Map<String, dynamic> patch) async {
    if (patch.isEmpty) return getCurrentUser();
    final response = await _client.patch(
      _uri("/users/me"),
      headers: await _headers(),
      body: jsonEncode(patch),
    );
    _ensureSuccess(response, "프로필 수정 실패");
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getVenue(String venueId) async {
    final response = await _client.get(_uri("/venues/$venueId"), headers: await _headers());
    _ensureSuccess(response, "구장 정보를 불러오지 못했습니다");
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<VenueSummary>> getVenues({String? area}) async {
    final response = await _client.get(_uri("/venues", area != null ? {"area": area} : null), headers: await _headers());
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (body["items"] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(VenueSummary.fromJson)
        .toList();
    return items;
  }

  Future<List<GroupSummary>> getVenueGroups(String venueId) async {
    final response = await _client.get(_uri("/venues/$venueId/groups"), headers: await _headers());
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (body["items"] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(GroupSummary.fromJson)
        .toList();
    return items;
  }

  Future<Map<String, dynamic>> getGroupDetail(String groupId) async {
    final response = await _client.get(_uri("/groups/$groupId"), headers: await _headers());
    _ensureSuccess(response, "모임 상세 조회 실패");
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> patchGroupProfile(String groupId, Map<String, dynamic> patch) async {
    if (patch.isEmpty) return getGroupDetail(groupId);
    final response = await _client.patch(
      _uri("/groups/$groupId"),
      headers: await _headers(),
      body: jsonEncode(patch),
    );
    _ensureSuccess(response, "모임 프로필 수정 실패");
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Membership> applyMembership(String groupId) async {
    final response = await _client.post(_uri("/groups/$groupId/join-requests"), headers: await _headers());
    _ensureSuccess(response, "가입 신청 실패");
    return Membership.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> getJoinRequests(String groupId) async {
    final response = await _client.get(_uri("/groups/$groupId/join-requests"), headers: await _headers());
    _ensureSuccess(response, "가입 신청 목록 조회 실패");
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body["items"] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> decideJoinRequest({
    required String groupId,
    required String membershipId,
    required bool approve,
  }) async {
    final response = await _client.patch(
      _uri("/groups/$groupId/join-requests/$membershipId"),
      headers: await _headers(),
      body: jsonEncode({"decision": approve ? "approve" : "reject"}),
    );
    _ensureSuccess(response, "신청 처리 실패");
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getFavorites() async {
    final response = await _client.get(_uri("/favorites"), headers: await _headers());
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body["items"] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addFavorite({
    required String targetType,
    required String targetId,
  }) async {
    final response = await _client.post(_uri("/favorites/$targetType/$targetId"), headers: await _headers());
    _ensureSuccess(response, "즐겨찾기 추가 실패");
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> removeFavorite({
    required String targetType,
    required String targetId,
  }) async {
    final response = await _client.delete(_uri("/favorites/$targetType/$targetId"), headers: await _headers());
    _ensureSuccess(response, "즐겨찾기 삭제 실패");
  }

  Future<List<Map<String, dynamic>>> getLightningMatches() async {
    final response = await _client.get(_uri("/lightning-matches"), headers: await _headers());
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body["items"] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createLightningMatch({
    required String venueId,
    required String level,
    required int capacity,
  }) async {
    final now = DateTime.now();
    final response = await _client.post(
      _uri("/lightning-matches"),
      headers: await _headers(),
      body: jsonEncode({
        "venueId": venueId,
        "level": level,
        "capacity": capacity,
        "startAt": now.toIso8601String(),
        "endAt": now.add(const Duration(hours: 2)).toIso8601String(),
      }),
    );
    _ensureSuccess(response, "번개 매칭 생성 실패");
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createReview({
    required String targetType,
    required String targetId,
    required int rating,
    String? comment,
  }) async {
    final response = await _client.post(
      _uri("/reviews"),
      headers: await _headers(),
      body: jsonEncode({
        "targetType": targetType,
        "targetId": targetId,
        "rating": rating,
        "comment": comment,
      }),
    );
    _ensureSuccess(response, "후기 등록 실패");
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// 공개 API — `x-user-id`는 그대로 전송(백엔드 hybrid 모드).
  Future<List<Map<String, dynamic>>> discoverMeetups({
    required double lat,
    required double lng,
    String sort = "distance",
  }) async {
    final response = await _client.get(
      _uri("/discover/meetups", {"lat": "$lat", "lng": "$lng", "sort": sort}),
      headers: await _headers(),
    );
    _ensureSuccess(response, "근처 모임 조회 실패");
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body["items"] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getCoaches() async {
    final response = await _client.get(_uri("/coaching/coaches"), headers: await _headers());
    _ensureSuccess(response, "코치 목록 조회 실패");
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body["items"] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> registerCoachProfile({
    required String bio,
    required int hourlyRateWon,
    List<String>? preferredVenueIds,
  }) async {
    final response = await _client.post(
      _uri("/coaching/register"),
      headers: await _headers(),
      body: jsonEncode({
        "bio": bio,
        "hourlyRateWon": hourlyRateWon,
        "preferredVenueIds": preferredVenueIds ?? [],
      }),
    );
    _ensureSuccess(response, "코치 등록 실패");
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createLessonBooking({
    required String coachUserId,
    required String startsAtIso,
    String? venueId,
    String? note,
  }) async {
    final response = await _client.post(
      _uri("/coaching/bookings"),
      headers: await _headers(),
      body: jsonEncode({
        "coachUserId": coachUserId,
        "startsAt": startsAtIso,
        if (venueId != null) "venueId": venueId,
        if (note != null) "note": note,
      }),
    );
    _ensureSuccess(response, "레슨 예약 요청 실패");
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMyLessonBookings() async {
    final response = await _client.get(_uri("/coaching/bookings/me"), headers: await _headers());
    _ensureSuccess(response, "예약 내역 조회 실패");
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateLessonBooking({
    required String bookingId,
    required String status,
  }) async {
    final response = await _client.patch(
      _uri("/coaching/bookings/$bookingId"),
      headers: await _headers(),
      body: jsonEncode({"status": status}),
    );
    _ensureSuccess(response, "예약 상태 변경 실패");
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getGroupPlaySessions(String groupId) async {
    final response = await _client.get(_uri("/groups/$groupId/play-sessions"), headers: await _headers());
    _ensureSuccess(response, "플레이 세션 목록 실패");
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body["items"] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> remindPlaySessionStart(String sessionId) async {
    final response = await _client.post(
      _uri("/play-sessions/$sessionId/remind-start"),
      headers: await _headers(),
    );
    _ensureSuccess(response, "시작 알림 전송 실패");
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<SocialAuthResult> socialLogin({
    required String provider,
    required String providerUserId,
    String? email,
    String? nickname,
  }) async {
    final response = await _client.post(
      _uri("/auth/social/$provider"),
      headers: await _headers(),
      body: jsonEncode({
        "providerUserId": providerUserId,
        "email": email,
        "nickname": nickname,
        "emailVerified": email != null,
      }),
    );
    _ensureSuccess(response, "소셜 로그인 실패");
    return SocialAuthResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
