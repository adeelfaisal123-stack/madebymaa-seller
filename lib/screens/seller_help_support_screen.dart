import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/seller_help_support.dart';
import '../services/optica2_api.dart';
import '../theme/app_colors.dart';
import '../widgets/app_toast.dart';

class SellerHelpSupportScreen extends StatefulWidget {
  const SellerHelpSupportScreen({super.key, this.initialContent});

  final SellerHelpSupport? initialContent;

  @override
  State<SellerHelpSupportScreen> createState() =>
      _SellerHelpSupportScreenState();
}

class _SellerHelpSupportScreenState extends State<SellerHelpSupportScreen> {
  final _api = Optica2Api();
  bool _loading = true;
  SellerHelpSupport _content = SellerHelpSupport.empty;
  int? _expandedFaqId;

  @override
  void initState() {
    super.initState();
    if (widget.initialContent != null) {
      _content = widget.initialContent!;
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final content = await _api.fetchSellerHelpSupport();
      if (!mounted) return;
      setState(() {
        _content = content;
        _loading = false;
      });
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.danger(context, e.message);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _launch(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) AppToast.danger(context, 'Could not open link.');
    }
  }

  Future<void> _callPhone(String value) async {
    final digits = value.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return;
    await _launch(Uri(scheme: 'tel', path: digits));
  }

  Future<void> _sendEmail(String value) async {
    await _launch(Uri(scheme: 'mailto', path: value));
  }

  Future<void> _openWhatsApp(String value) async {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    await _launch(Uri.parse('https://wa.me/$digits'));
  }

  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandPurple, AppColors.brandPurpleDeep],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPurple.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _content.title,
            style: GoogleFonts.exo2(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.15,
            ),
          ),
          if (_content.subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _content.subtitle,
              style: GoogleFonts.exo2(
                fontSize: 14,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ],
          if (_content.hours.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _content.hours,
                    style: GoogleFonts.exo2(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _contactButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: GoogleFonts.exo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepGreen,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _faqTile(SellerFaq faq) {
    final expanded = _expandedFaqId == faq.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: expanded
                ? AppColors.brandPurple.withValues(alpha: 0.35)
                : AppColors.brandPurple.withValues(alpha: 0.12),
          ),
          boxShadow: expanded
              ? [
                  BoxShadow(
                    color: AppColors.brandPurple.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(
              () => _expandedFaqId = expanded ? null : faq.id,
            ),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.brandPurple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.quiz_outlined,
                          size: 16,
                          color: AppColors.brandPurple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          faq.question,
                          style: GoogleFonts.exo2(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepGreen,
                            height: 1.35,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Icon(
                          Icons.expand_more_rounded,
                          color: AppColors.deepGreen.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(left: 40, top: 10),
                      child: Text(
                        faq.answer,
                        style: GoogleFonts.exo2(
                          fontSize: 13,
                          height: 1.55,
                          color: AppColors.deepGreen.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                    crossFadeState: expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 220),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.deepGreen),
        title: Text(
          'Help & Support',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brandPurple),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _heroCard(),
                if (_content.body.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.brandPurple.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      _content.body,
                      style: GoogleFonts.exo2(
                        fontSize: 14,
                        height: 1.55,
                        color: AppColors.deepGreen.withValues(alpha: 0.82),
                      ),
                    ),
                  ),
                ],
                if (_content.hasFaqs) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        'FAQs',
                        style: GoogleFonts.exo2(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepGreen,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandPurple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_content.faqs.length}',
                          style: GoogleFonts.exo2(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandPurple,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._content.faqs.map(_faqTile),
                ],
                if (_content.hasContact) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Still need help?',
                    style: GoogleFonts.exo2(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepGreen,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Reach our support team directly.',
                    style: GoogleFonts.exo2(
                      fontSize: 13,
                      color: AppColors.deepGreen.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (_content.phone.isNotEmpty)
                        _contactButton(
                          icon: Icons.phone_in_talk_rounded,
                          label: 'Call',
                          color: AppColors.sage,
                          onTap: () => _callPhone(_content.phone),
                        ),
                      if (_content.phone.isNotEmpty &&
                          (_content.email.isNotEmpty ||
                              _content.whatsapp.isNotEmpty))
                        const SizedBox(width: 10),
                      if (_content.email.isNotEmpty)
                        _contactButton(
                          icon: Icons.mail_outline_rounded,
                          label: 'Email',
                          color: AppColors.brandPurple,
                          onTap: () => _sendEmail(_content.email),
                        ),
                      if (_content.email.isNotEmpty &&
                          _content.whatsapp.isNotEmpty)
                        const SizedBox(width: 10),
                      if (_content.whatsapp.isNotEmpty)
                        _contactButton(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'WhatsApp',
                          color: AppColors.kitchenOpen,
                          onTap: () => _openWhatsApp(_content.whatsapp),
                        ),
                    ],
                  ),
                ],
                if (!_content.hasContact &&
                    !_content.hasFaqs &&
                    _content.body.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Center(
                      child: Text(
                        'Support details are not available yet. Please check back later.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.exo2(
                          color: AppColors.deepGreen.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
