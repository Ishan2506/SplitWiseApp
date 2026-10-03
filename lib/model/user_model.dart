class UserModel {
  final String id;
  final String name;
  final String? email;
  final String? mobileNumber;
  final String avatarUrl;
  final String preferredCurrency;

  /// Where this user wants to be paid back — empty when not set. Shown to
  /// fellow group members so Settle up can open a pre-filled payment.
  final String upiId;
  final String paypalMe;
  final String language;
  final bool emailNotifications;
  final bool pushNotifications;
  final bool emailSummaryEnabled;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    this.email,
    this.mobileNumber,
    required this.avatarUrl,
    required this.preferredCurrency,
    this.upiId = '',
    this.paypalMe = '',
    required this.language,
    required this.emailNotifications,
    required this.pushNotifications,
    required this.emailSummaryEnabled,
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
      upiId: json['upiId'] ?? '',
      paypalMe: json['paypalMe'] ?? '',
      language: json['language'] ?? 'en',
      emailNotifications: json['emailNotifications'] ?? true,
      // Off by default — matches the server's User.pushNotifications
      // default; a user has to explicitly switch it on.
      pushNotifications: json['pushNotifications'] ?? false,
      emailSummaryEnabled: json['emailSummaryEnabled'] ?? false,
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
      'upiId': upiId,
      'paypalMe': paypalMe,
      'language': language,
      'emailNotifications': emailNotifications,
      'pushNotifications': pushNotifications,
      'emailSummaryEnabled': emailSummaryEnabled,
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
