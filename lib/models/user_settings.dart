/// Nastavitve uporabnika, shranjene v shared_preferences
class UserSettings {
  final String taxNumber; // davčna številka (8 številk)
  final String fullName;
  final String email;
  final String phoneNumber;
  final bool isResident; // rezident RS

  const UserSettings({
    required this.taxNumber,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.isResident = true,
  });

  /// Prazen objekt za inicializacijo
  static const empty = UserSettings(
    taxNumber: '',
    fullName: '',
    email: '',
    phoneNumber: '',
    isResident: true,
  );

  bool get isValid =>
      taxNumber.length == 8 &&
      RegExp(r'^\d{8}$').hasMatch(taxNumber) &&
      fullName.isNotEmpty;

  UserSettings copyWith({
    String? taxNumber,
    String? fullName,
    String? email,
    String? phoneNumber,
    bool? isResident,
  }) {
    return UserSettings(
      taxNumber: taxNumber ?? this.taxNumber,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isResident: isResident ?? this.isResident,
    );
  }

  Map<String, dynamic> toJson() => {
    'taxNumber': taxNumber,
    'fullName': fullName,
    'email': email,
    'phoneNumber': phoneNumber,
    'isResident': isResident,
  };

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
    taxNumber: json['taxNumber'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phoneNumber: json['phoneNumber'] as String? ?? '',
    isResident: json['isResident'] as bool? ?? true,
  );
}