class User {
  final int id;
  final String username;
  final String email;
  final String? avatarUrl;
  final String timezone;
  final bool isActive;
  final bool isAdmin;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    required this.timezone,
    required this.isActive,
    this.isAdmin = false,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      avatarUrl: json['avatar_url'],
      timezone: json['timezone'] ?? 'UTC',
      isActive: json['is_active'] ?? true,
      isAdmin: json['is_admin'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
