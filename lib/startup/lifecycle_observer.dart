import 'package:flutter/material.dart';
import 'package:ludo_prince/services/audio_service.dart';
import 'package:ludo_prince/services/presence_service.dart';

/// Mixin to observe app lifecycle and manage BGM + presence.
/// Use with a [State] subclass that also mixes in [WidgetsBindingObserver].
mixin AppLifecycleHandler<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      audioService.pauseBGM();
    } else if (state == AppLifecycleState.resumed) {
      audioService.resumeBGM();
    }
  }

  void initLifecycleObserver() {
    WidgetsBinding.instance.addObserver(this);
    presenceService.setPresence();
  }

  void disposeLifecycleObserver() {
    WidgetsBinding.instance.removeObserver(this);
    presenceService.dispose();
  }
}
