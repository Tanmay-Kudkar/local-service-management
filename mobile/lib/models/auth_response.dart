class AuthResponse {
  final int userId;
  final String message;

  AuthResponse({required this.userId, required this.message});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      userId: json['userId'] as int,
      message: json['message'] as String,
    );
  }
}