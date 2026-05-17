class AppUser {
  final String uid;
  final String email;
  final String name;
  final String role;
  final String? photoUrl;
  final String? phone;
  final bool profileComplete;
  final String? fcmToken;

  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.photoUrl,
    this.phone,
    this.profileComplete = false,
    this.fcmToken,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        uid: j['uid'] ?? '',
        email: j['email'] ?? '',
        name: j['name'] ?? '',
        role: j['role'] ?? 'customer',
        photoUrl: j['photo_url'],
        phone: j['phone'],
        profileComplete: j['profile_complete'] ?? false,
        fcmToken: j['fcm_token'],
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'name': name,
        'role': role,
        'photo_url': photoUrl,
        'phone': phone,
        'profile_complete': profileComplete,
        'fcm_token': fcmToken,
      };
}
