import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SnackBarState {
  final String message;
  final IconData icon;
  final Color? color;
  final bool isError;
  final bool isSuccess;
  final Duration duration;
  final DateTime timestamp;

  SnackBarState({
    required this.message,
    this.icon = Icons.info_outline,
    this.color,
    this.isError = false,
    this.isSuccess = false,
    required this.duration,
    required this.timestamp,
  });
}

class SnackBarNotifier extends Notifier<SnackBarState?> {
  Timer? _dismissTimer;

  @override
  SnackBarState? build() {
    ref.onDispose(() => _dismissTimer?.cancel());
    return null;
  }

  void show({
    required String message,
    IconData icon = Icons.info_outline,
    Color? color,
    bool isError = false,
    bool isSuccess = false,
    Duration? duration,
  }) {
    // Deduplicate same message within 2 seconds
    final currentState = state;
    if (currentState != null &&
        currentState.message == message &&
        DateTime.now().difference(currentState.timestamp).inSeconds < 2) {
      return;
    }

    _dismissTimer?.cancel();

    final calculatedDuration =
        duration ??
        Duration(
          milliseconds: (2000 + (message.length * 50)).clamp(3000, 7000),
        );

    state = SnackBarState(
      message: message,
      icon: icon,
      color: color,
      isError: isError,
      isSuccess: isSuccess,
      duration: calculatedDuration,
      timestamp: DateTime.now(),
    );

    _dismissTimer = Timer(calculatedDuration, () {
      state = null;
    });
  }

  void hide() {
    _dismissTimer?.cancel();
    state = null;
  }
}

final snackBarProvider = NotifierProvider<SnackBarNotifier, SnackBarState?>(() {
  return SnackBarNotifier();
});
