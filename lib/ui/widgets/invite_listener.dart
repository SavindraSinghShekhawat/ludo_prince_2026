import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/social_service.dart';
import '../dialogs/invite_dialog.dart';

class InviteListener extends StatefulWidget {
  final Widget child;
  const InviteListener({super.key, required this.child});

  @override
  State<InviteListener> createState() => _InviteListenerState();
}

class _InviteListenerState extends State<InviteListener> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = socialService.watchInvites().listen((event) {
      if (event.snapshot.value != null && mounted) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final inviteId = event.snapshot.key!;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => InviteDialog(
            inviteId: inviteId,
            fromName: data['fromName'] ?? 'Someone',
            gameId: data['gameId'],
            joiningCode: data['joiningCode'],
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
