class UserProfile {
  final int userId;
  final String name;
  final String email;
  final String role;

  UserProfile({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: (json['userId'] as num).toInt(),
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
    );
  }
}