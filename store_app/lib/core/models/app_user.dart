/// Mirrors backend `TokenVerifyResponse`.
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String role; // customer | store_owner | delivery | admin
  final bool isActive;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.isActive,
  });

  bool get isStoreOwner => role == 'store_owner';
  bool get isDeliveryBoy => role == 'delivery';
  bool get isAdmin => role == 'admin';

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        uid: json['uid'] as String,
        email: (json['email'] ?? '') as String,
        displayName: (json['display_name'] ?? '') as String,
        role: (json['role'] ?? 'customer') as String,
        isActive: (json['is_active'] ?? true) as bool,
      );
}
