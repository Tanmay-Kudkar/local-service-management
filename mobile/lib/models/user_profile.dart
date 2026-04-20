class UserProfile {
  final int userId;
  final String name;
  final String email;
  final String role;
  final String? contactNumber;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? profileImageUrl;
  final int? experienceYears;
  final String? skills;
  final String? bio;
  final bool verified;
  final double ratingAverage;
  final int totalReviews;

  UserProfile({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.contactNumber,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.profileImageUrl,
    this.experienceYears,
    this.skills,
    this.bio,
    this.verified = false,
    this.ratingAverage = 0,
    this.totalReviews = 0,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: (json['userId'] as num).toInt(),
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      contactNumber: json['contactNumber'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
      experienceYears: (json['experienceYears'] as num?)?.toInt(),
      skills: json['skills'] as String?,
      bio: json['bio'] as String?,
      verified: (json['verified'] as bool?) ?? false,
      ratingAverage: ((json['ratingAverage'] as num?) ?? 0).toDouble(),
      totalReviews: (json['totalReviews'] as num?)?.toInt() ?? 0,
    );
  }
}