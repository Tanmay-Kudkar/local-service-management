class AuthResponse {
  final int userId;
  final String name;
  final String role;
  final String message;

  AuthResponse({
    required this.userId,
    required this.name,
    required this.role,
    required this.message,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      userId: json['userId'] as int,
      name: (json['name'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'USER',
      message: json['message'] as String,
    );
  }
}