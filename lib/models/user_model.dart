class UserModel {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final id =
        (json['id'] ??
                json['userId'] ??
                json['_id'] ??
                json['uuid'] ??
                json['email'] ??
                '')
            .toString();

    final email = (json['email'] ?? '').toString();
    final name =
        (json['name'] ?? json['fullName'] ?? json['displayName'] ?? email)
            .toString();
    final avatarUrl = (json['avatarUrl'] ??
            json['avatar'] ??
            json['photoUrl'] ??
            json['picture'])
        ?.toString();

    return UserModel(
      id: id,
      email: email,
      name: name,
      avatarUrl: avatarUrl == null || avatarUrl.isEmpty ? null : avatarUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'avatarUrl': avatarUrl,
  };
}
