class AppUser {
  final int id;
  final String username;
  final String nombre;
  final List<String> roles;

  AppUser({
    required this.id,
    required this.username,
    required this.nombre,
    required this.roles,
  });

  String get primaryRole => roles.isNotEmpty ? roles.first : 'UNKNOWN';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['id'] as num).toInt(),
      username: (json['username'] as String),
      nombre: (json['nombre'] as String),
      roles: List<String>.from(json['roles'] ?? []),
    );
  }
}
