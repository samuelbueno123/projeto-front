class AuthSession {
  const AuthSession({
    required this.isAuthenticated,
    this.token,
    this.refreshToken,
    this.userName,
    this.userEmail,
    this.provider = 'password',
  });

  final bool isAuthenticated;
  final String? token;
  final String? refreshToken;
  final String? userName;
  final String? userEmail;
  final String provider;

  AuthSession copyWith({
    bool? isAuthenticated,
    String? token,
    String? refreshToken,
    String? userName,
    String? userEmail,
    String? provider,
  }) {
    return AuthSession(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      provider: provider ?? this.provider,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isAuthenticated': isAuthenticated,
      'token': token,
      'refreshToken': refreshToken,
      'userName': userName,
      'userEmail': userEmail,
      'provider': provider,
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      isAuthenticated: json['isAuthenticated'] == true,
      token: json['token'] as String?,
      refreshToken: json['refreshToken'] as String?,
      userName: json['userName'] as String?,
      userEmail: json['userEmail'] as String?,
      provider: json['provider'] as String? ?? 'password',
    );
  }
}
