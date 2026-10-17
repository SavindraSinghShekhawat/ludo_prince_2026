import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/services/device_info_service.dart';
import 'package:ludo_prince/services/feedback_service.dart';
import 'package:ludo_prince/services/smart_review_service.dart';
import '../widgets/shared_ui.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  final int? initialRating;

  const FeedbackScreen({super.key, this.initialRating});

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
      if (widget.initialRating != null) {
        await SmartReviewService.instance.recordConstructiveFeedback(
          rating: widget.initialRating!,
          message: message,
        );
      } else {
        await ref
            .read(feedbackServiceProvider)
            .submitFeedback(message, deviceMetadata: deviceMetadata);
      }
      if (mounted) {
        _feedbackController.clear();
        AppSnackBar.show(
          context,
          message: 'Thank you for your feedback! We will improve your experience.',
          isSuccess: true,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
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
    return AppBackground(
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
                      if (widget.initialRating != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E4E2).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFE5E4E2).withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star_half_rounded,
                                color: Color(0xFFE5E4E2),
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "We'd love to make Ludo Prince a 5-star experience for you. What can we improve?",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
