import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> submitFeedback(String message) async {
    final user = _auth.currentUser;
    final userId = user?.uid ?? 'anonymous';

    // Fallback name logic consistent with auth_provider.dart
    String displayName = "Guest";
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        displayName = user.displayName!;
      } else {
        final uid = user.uid;
        final shortUid = uid.length > 4 ? uid.substring(uid.length - 4) : uid;
        displayName = "Guest #${shortUid.toUpperCase()}";
      }
    }

    await _firestore.collection('feedbacks').add({
      'userId': userId,
      'userName': displayName,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}

final feedbackServiceProvider = Provider((ref) => FeedbackService());
