import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/device_info_service.dart';
import '../../services/feedback_service.dart';
import '../widgets/shared_ui.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _feedbackController = TextEditingController();
  bool _isFeedbackSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final message = _feedbackController.text.trim();
    if (message.isEmpty) return;

    setState(() => _isFeedbackSubmitting = true);

    try {
      final deviceMetadata = await ref.read(deviceMetadataProvider.future);
      await ref
          .read(feedbackServiceProvider)
          .submitFeedback(message, deviceMetadata: deviceMetadata);
      if (mounted) {
        _feedbackController.clear();
        CustomSnackBar.show(
          context,
          message: 'Thank you for your feedback!',
          isSuccess: true,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Failed to send feedback. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isFeedbackSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'SHARE FEEDBACK',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "HELP US IMPROVE",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 16),
                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "To help us debug, app version and device metadata (OS, model) will be attached automatically.",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextField(
                        controller: _feedbackController,
                        maxLines: 8,
                        style: const TextStyle(color: Colors.white),
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText:
                              "Tell us about your experience or report a bug...",
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed:
                            _isFeedbackSubmitting ? null : _submitFeedback,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          backgroundColor: Colors.transparent,
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFE5E4E2), // Platinum
                                Color(0xFFB0B4B8), // Silver
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            child: _isFeedbackSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  )
                                : const Text(
                                    "SUBMIT FEEDBACK",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Your feedback helps us make Ludo Prince better for everyone. We read every submission!",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white24, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
