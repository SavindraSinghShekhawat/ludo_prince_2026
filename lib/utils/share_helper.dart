import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';

class ShareHelper {
  static const String androidLink =
      'https://play.google.com/store/apps/details?id=com.paisphere.ludoprince';
  static const String iosLink =
      'https://apps.apple.com/app/id6760012267'; // Replace with actual App ID

  static Future<void> shareApp(BuildContext context) async {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Rect? sharePositionOrigin =
        box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;

    final String fullMessage =
        'Ready to be the next Ludo Prince? ✨ Join me for the ultimate Ludo experience! Download Ludo Prince now and let\'s see who rules the board! ⚔️🎲\n\nAndroid: $androidLink\niOS: $iosLink';

    await Share.share(
      fullMessage,
      subject: 'Invite to Ludo Prince',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  static Future<void> shareGameId(BuildContext context, String gameId) async {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Rect? sharePositionOrigin =
        box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;

    final String message =
        "The board is set, the dice are ready! 🎲 I'm waiting for you in the Ludo Prince lobby. Use Game ID: $gameId to join my game and win the match! ✨⚔️🎲\n\nAndroid: $androidLink\niOS: $iosLink";
    await Share.share(
      message,
      subject: 'Ludo Prince Game Invitation',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  static Future<void> shareJoiningCode(
      BuildContext context, String code) async {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Rect? sharePositionOrigin =
        box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;

    final String message =
        "The board is set, the dice are ready! 🎲 I'm waiting for you in the Ludo Prince lobby. JOINING CODE: $code\n\nEnter this code in 'Play with Friends' -> 'Join Room' to start the match! ✨⚔️🎲\n\nAndroid: $androidLink\niOS: $iosLink";

    await Share.share(
      message,
      subject: 'Ludo Prince Game Invitation',
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}
