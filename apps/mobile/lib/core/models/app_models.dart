class VenueSummary {
  VenueSummary({
    required this.id,
    required this.name,
    required this.address,
    required this.courtCount,
    required this.ratingAvg,
  });

  final String id;
  final String name;
  final String address;
  final int courtCount;
  final double ratingAvg;

  factory VenueSummary.fromJson(Map<String, dynamic> json) {
    return VenueSummary(
      id: json["id"] as String,
      name: json["name"] as String,
      address: json["address"] as String,
      courtCount: (json["courtCount"] as num?)?.toInt() ?? 0,
      ratingAvg: (json["ratingAvg"] as num?)?.toDouble() ?? 0,
    );
  }
}

class GroupSummary {
  GroupSummary({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.status,
    required this.memberCount,
    required this.maxMembers,
  });

  final String id;
  final String name;
  final String? photoUrl;
  final String status;
  final int memberCount;
  final int maxMembers;

  factory GroupSummary.fromJson(Map<String, dynamic> json) {
    return GroupSummary(
      id: json["id"] as String,
      name: json["name"] as String,
      photoUrl: json["photoUrl"] as String?,
      status: json["status"] as String? ?? "recruiting",
      memberCount: (json["memberCount"] as num?)?.toInt() ?? 0,
      maxMembers: (json["maxMembers"] as num?)?.toInt() ?? 0,
    );
  }
}

class Membership {
  Membership({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.status,
  });

  final String id;
  final String groupId;
  final String userId;
  final String status;

  factory Membership.fromJson(Map<String, dynamic> json) {
    return Membership(
      id: json["id"] as String,
      groupId: json["groupId"] as String,
      userId: json["userId"] as String,
      status: json["status"] as String? ?? "applied",
    );
  }
}

class SocialAuthResult {
  SocialAuthResult({
    required this.accessToken,
    required this.userId,
    required this.supabaseAccessToken,
    required this.supabaseRefreshToken,
  });

  final String accessToken;
  final String userId;
  final String supabaseAccessToken;
  final String supabaseRefreshToken;

  factory SocialAuthResult.fromJson(Map<String, dynamic> json) {
    final user = (json["user"] as Map<String, dynamic>? ?? const {});
    return SocialAuthResult(
      accessToken: json["accessToken"] as String? ?? "",
      userId: user["id"] as String? ?? "",
      supabaseAccessToken: json["supabaseAccessToken"] as String? ?? "",
      supabaseRefreshToken: json["supabaseRefreshToken"] as String? ?? "",
    );
  }
}
