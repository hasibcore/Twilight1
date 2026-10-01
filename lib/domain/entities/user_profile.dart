class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String avatarUrl;
  final bool isGuest;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.avatarUrl,
    this.isGuest = false,
  });
}
