import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoURL;
  final int friendsCount;
  final int gamesPlayed;
  final int gamesWon;
  final DateTime createdAt;
  final DateTime? lastActive;

  UserProfile({
    required this.uid,
    this.displayName,
    this.email,
    this.photoURL,
    this.friendsCount = 0,
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    required this.createdAt,
    this.lastActive,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      displayName: data['displayName'],
      email: data['email'],
      photoURL: data['photoURL'],
      friendsCount: data['friendsCount'] ?? 0,
      gamesPlayed: data['gamesPlayed'] ?? 0,
      gamesWon: data['gamesWon'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastActive: data['lastActive'] != null
          ? (data['lastActive'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'photoURL': photoURL,
      'friendsCount': friendsCount,
      'gamesPlayed': gamesPlayed,
      'gamesWon': gamesWon,
      'createdAt': createdAt,
      'lastActive': FieldValue.serverTimestamp(),
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? email,
    String? photoURL,
    int? friendsCount,
    int? gamesPlayed,
    int? gamesWon,
    DateTime? lastActive,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
      friendsCount: friendsCount ?? this.friendsCount,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      gamesWon: gamesWon ?? this.gamesWon,
      createdAt: createdAt,
      lastActive: lastActive ?? this.lastActive,
    );
  }
}
