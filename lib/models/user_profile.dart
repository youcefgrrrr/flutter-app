import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    this.phone,
    this.city,
  });

  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final DateTime birthDate;
  final String? phone;
  final String? city;

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toMap() => {
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'birthDate': Timestamp.fromDate(birthDate),
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (city != null && city!.isNotEmpty) 'city': city,
      };

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    final birth = map['birthDate'];
    return UserProfile(
      uid: uid,
      email: map['email'] as String? ?? '',
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      birthDate: birth is Timestamp
          ? birth.toDate()
          : DateTime.tryParse(birth?.toString() ?? '') ?? DateTime(2000),
      phone: map['phone'] as String?,
      city: map['city'] as String?,
    );
  }
}
