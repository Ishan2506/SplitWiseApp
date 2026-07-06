class UserModel {
  final String id;
  final String name;
  final String? email;
  final String? mobileNumber;
  final String avatarUrl;
  final String preferredCurrency;
  final String language;
  final bool emailNotifications;
  final bool pushNotifications;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    this.email,
    this.mobileNumber,
    required this.avatarUrl,
    required this.preferredCurrency,
    required this.language,
    required this.emailNotifications,
    required this.pushNotifications,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'],
      mobileNumber: json['mobileNumber'],
      avatarUrl: json['avatarUrl'] ?? '',
      preferredCurrency: json['preferredCurrency'] ?? 'INR',
      language: json['language'] ?? 'en',
      emailNotifications: json['emailNotifications'] ?? true,
      pushNotifications: json['pushNotifications'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'mobileNumber': mobileNumber,
      'avatarUrl': avatarUrl,
      'preferredCurrency': preferredCurrency,
      'language': language,
      'emailNotifications': emailNotifications,
      'pushNotifications': pushNotifications,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String get initials {
    if (name.isEmpty) return "?";
    final parts = name.trim().split(" ");
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}
