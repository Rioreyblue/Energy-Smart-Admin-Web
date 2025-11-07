import '../../utils/logger.dart';

class AdminUser {
  final String id;
  final String email;
  final String role;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final bool isActive;
  final Map<String, bool> permissions;
  final String? photoUrl;

  AdminUser({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
    this.lastLogin,
    this.isActive = true,
    this.permissions = const {},
    this.photoUrl,
  });

  factory AdminUser.fromMap(Map<String, dynamic> map) {
    try {
      // Handle missing or null fields gracefully
      final id = map['id']?.toString() ?? '';
      final email = map['email']?.toString() ?? '';
      final role = map['role']?.toString() ?? 'admin';
      final String? photoUrl =
          (map['photo_url'] ?? map['photoUrl'])?.toString();

      // Handle created_at with better error handling
      DateTime createdAt;
      if (map['created_at'] != null) {
        try {
          createdAt = DateTime.fromMillisecondsSinceEpoch(map['created_at']);
        } catch (e) {
          Logger.error('Error parsing created_at', e);
          createdAt = DateTime.now();
        }
      } else {
        createdAt = DateTime.now();
      }

      // Handle last_login with better error handling
      DateTime? lastLogin;
      if (map['last_login'] != null) {
        try {
          lastLogin = DateTime.fromMillisecondsSinceEpoch(map['last_login']);
        } catch (e) {
          Logger.error('Error parsing last_login', e);
          lastLogin = null;
        }
      }

      // Handle is_active field
      bool isActive = true;
      if (map['is_active'] != null) {
        if (map['is_active'] is bool) {
          isActive = map['is_active'];
        } else if (map['is_active'] is String) {
          isActive = map['is_active'].toLowerCase() == 'true';
        }
      }

      // Handle permissions with better error handling
      Map<String, bool> permissions = {};
      if (map['permissions'] != null) {
        try {
          if (map['permissions'] is Map) {
            permissions = Map<String, bool>.from(map['permissions']);
          }
        } catch (e) {
          Logger.error('Error parsing permissions', e);
          permissions = {};
        }
      }

      return AdminUser(
        id: id,
        email: email,
        role: role,
        createdAt: createdAt,
        lastLogin: lastLogin,
        isActive: isActive,
        permissions: permissions,
        photoUrl: photoUrl,
      );
    } catch (e) {
      Logger.error('Error creating AdminUser from map', e);
      Logger.debug('Map data: $map');
      // Return a default admin user to prevent complete failure
      return AdminUser(
        id: map['id']?.toString() ?? '',
        email: map['email']?.toString() ?? '',
        role: 'admin',
        createdAt: DateTime.now(),
        isActive: true,
        permissions: {},
        photoUrl: (map['photo_url'] ?? map['photoUrl'])?.toString(),
      );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'created_at': createdAt.millisecondsSinceEpoch,
      'last_login': lastLogin?.millisecondsSinceEpoch,
      'is_active': isActive,
      'permissions': permissions,
      if (photoUrl != null) 'photo_url': photoUrl,
    };
  }

  AdminUser copyWith({
    String? id,
    String? email,
    String? role,
    DateTime? createdAt,
    DateTime? lastLogin,
    bool? isActive,
    Map<String, bool>? permissions,
    String? photoUrl,
  }) {
    return AdminUser(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      isActive: isActive ?? this.isActive,
      permissions: permissions ?? this.permissions,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  bool get isSuperAdmin => role == 'super_admin';
  bool get isAdmin => role == 'admin' || isSuperAdmin;

  bool hasPermission(String permission) {
    return permissions[permission] ?? false;
  }
}

class AdminAuthState {
  final AdminUser? user;
  final bool isLoading;
  final String? error;

  AdminAuthState({this.user, this.isLoading = false, this.error});

  AdminAuthState copyWith({AdminUser? user, bool? isLoading, String? error}) {
    return AdminAuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool get isAuthenticated => user != null && user!.isActive;
  bool get isNotAuthenticated => !isAuthenticated;
}
