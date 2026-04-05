import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_profile.dart';

class FriendRequest {
  final String id;
  final String fromUid;
  final String toUid;
  final String status;
  final DateTime timestamp;
  final UserProfile? fromProfile;

  FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.status,
    required this.timestamp,
    this.fromProfile,
  });

  factory FriendRequest.fromFirestore(DocumentSnapshot doc,
      {UserProfile? fromProfile}) {
    final data = doc.data() as Map<String, dynamic>;
    return FriendRequest(
      id: doc.id,
      fromUid: data['from'] ?? '',
      toUid: data['to'] ?? '',
      status: data['status'] ?? 'pending',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fromProfile: fromProfile,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'from': fromUid,
      'to': toUid,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
