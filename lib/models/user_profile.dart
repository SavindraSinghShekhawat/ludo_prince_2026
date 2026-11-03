import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoURL;
  final int friendsCount;
  final int gamesPlayed;
  final int gamesWon;
  final bool isAnonymous;
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
    this.isAnonymous = false,
    required this.createdAt,
    this.lastActive,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data();
    final Map<String, dynamic> data =
        rawData is Map ? Map<String, dynamic>.from(rawData) : <String, dynamic>{};

    // Safe boolean parsing
    bool isAnonymous = false;
    final isAnonRaw = data['isAnonymous'];
    if (isAnonRaw is bool) {
      isAnonymous = isAnonRaw;
    } else if (isAnonRaw is String) {
      isAnonymous = isAnonRaw.toLowerCase() == 'true';
    } else {
      final email = data['email']?.toString();
      final name = data['displayName']?.toString();
      isAnonymous = (email == null || email.isEmpty) &&
          (name == null ||
              name.isEmpty ||
              name.startsWith('Player ') ||
              name.startsWith('Guest #'));
    }

    int parseInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    DateTime parseDate(dynamic val, {DateTime? fallback}) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      if (val is num) {
        try {
          return DateTime.fromMillisecondsSinceEpoch(val.toInt());
        } catch (_) {}
      }
      return fallback ?? DateTime.now();
    }

    return UserProfile(
      uid: doc.id,
      displayName: data['displayName']?.toString(),
      email: data['email']?.toString(),
      photoURL: data['photoURL']?.toString(),
      friendsCount: parseInt(data['friendsCount']),
      gamesPlayed: parseInt(data['gamesPlayed']),
      gamesWon: parseInt(data['gamesWon']),
      isAnonymous: isAnonymous,
      createdAt: parseDate(data['createdAt']),
      lastActive:
          data['lastActive'] != null ? parseDate(data['lastActive']) : null,
    );
  }

  factory UserProfile.fromMap(Map<String, dynamic> data) {
    int parseInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    DateTime parseDate(dynamic val, {DateTime? fallback}) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      if (val is num) {
        try {
          return DateTime.fromMillisecondsSinceEpoch(val.toInt());
        } catch (_) {}
      }
      return fallback ?? DateTime.now();
    }

    final isAnonRaw = data['isAnonymous'];
    final bool isAnonymous = isAnonRaw is bool
        ? isAnonRaw
        : (isAnonRaw is String ? isAnonRaw.toLowerCase() == 'true' : false);

    return UserProfile(
      uid: data['uid']?.toString() ?? '',
      displayName: data['displayName']?.toString(),
      email: data['email']?.toString(),
      photoURL: data['photoURL']?.toString(),
      friendsCount: parseInt(data['friendsCount']),
      gamesPlayed: parseInt(data['gamesPlayed']),
      gamesWon: parseInt(data['gamesWon']),
      isAnonymous: isAnonymous,
      createdAt: parseDate(data['createdAt']),
      lastActive:
          data['lastActive'] != null ? parseDate(data['lastActive']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoURL': photoURL,
      'friendsCount': friendsCount,
      'gamesPlayed': gamesPlayed,
      'gamesWon': gamesWon,
      'isAnonymous': isAnonymous,
      'createdAt': createdAt.toIso8601String(),
      'lastActive': lastActive?.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore({bool isCreate = false}) {
    final map = <String, dynamic>{
      'displayName': displayName,
      'email': email,
      'photoURL': photoURL,
      'isAnonymous': isAnonymous,
      'lastActive': FieldValue.serverTimestamp(),
    };
    if (isCreate) {
      map['createdAt'] = createdAt;
    }
    return map;
  }

  UserProfile copyWith({
    String? displayName,
    String? email,
    String? photoURL,
    int? friendsCount,
    int? gamesPlayed,
    int? gamesWon,
    bool? isAnonymous,
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
      isAnonymous: isAnonymous ?? this.isAnonymous,
      createdAt: createdAt,
      lastActive: lastActive ?? this.lastActive,
    );
  }
}
