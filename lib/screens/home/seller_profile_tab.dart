import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/seller_address_info.dart';
import '../../models/seller_account_profile.dart';
import '../../models/seller_document_kyc_info.dart';
import '../../models/seller_wallet.dart';
import '../../seller_auth_prefs.dart';
import '../../seller_session_prefs.dart';
import '../../services/optica2_api.dart';
import '../../services/seller_auth_navigation.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_system_ui.dart';
import '../phone_auth_screen.dart';
import '../../models/seller_legal_document.dart';
import '../legal_document_screen.dart';
import '../../utils/msg91_phone.dart';
import '../seller_address_screen.dart';
import '../seller_edit_profile_screen.dart';
import '../seller_notifications_screen.dart';
import '../seller_wallet_screen.dart';
import '../register_seller_screen.dart';
import '../seller_help_support_screen.dart';

class SellerProfileTab extends StatefulWidget {
  const SellerProfileTab({super.key});

  @override
  State<SellerProfileTab> createState() => _SellerProfileTabState();
}

class _SellerProfileTabState extends State<SellerProfileTab> {
  final _api = Optica2Api();
  bool _loadingKyc = true;
  SellerDocumentKycStatusKind _documentKycStatus =
      SellerDocumentKycStatusKind.notSubmitted;
  SellerDocumentKycInfo? _documentKyc;
  double? _walletBalance;
  SellerAccountProfile? _accountProfile;
  SellerLegalDocuments? _legalDocuments;
  bool _kitchenSetupPending = false;

  @override
  void initState() {
    super.initState();
    _loadKycStatus();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _loadKycStatus() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();
    if (phone == null || phone.isEmpty) {
      if (mounted) setState(() => _loadingKyc = false);
      return;
    }

    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final result = await _api.fetchSellerKycStatus(
        phoneE164: phone,
        sellerId: sellerId,
      );
      SellerLegalDocuments? legal;
      try {
        legal = await _api.fetchSellerLegalDocuments();
      } catch (_) {
        // Legal docs load on tap if prefetch fails.
      }
      double? walletBalance;
      try {
        final wallet = await _api.fetchWallet(
          phoneE164: phone,
          sellerId: sellerId,
        );
        walletBalance = wallet.balance;
      } catch (_) {
        // Wallet optional on profile load.
      }
      if (!mounted) return;
      setState(() {
        _documentKycStatus = result.documentKycStatus;
        _documentKyc = result.documentKyc ??
            SellerDocumentKycInfo(
              status: result.documentKycStatus,
              hasUploads: false,
            );
        _accountProfile = _profileFromKycResult(result, phone);
        _legalDocuments = legal;
        _walletBalance = walletBalance;
        _kitchenSetupPending = result.kitchenSetupPending;
        _loadingKyc = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingKyc = false);
    }
  }

  Future<void> _onKycStatusTap() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();
    if (phone == null || phone.isEmpty || !mounted) return;

    await SellerAuthNavigation.openDocumentKycFlow(
      context,
      phoneE164: phone,
      status: _documentKycStatus,
      documentKyc: _documentKyc,
    );

    if (!mounted) return;
    await _loadKycStatus();
  }

  Future<void> _onKitchenSetupTap() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();
    if (phone == null || phone.isEmpty || !mounted) return;

    final sellerId =
        _accountProfile?.id ?? await SellerSessionPrefs.sellerId();
    if (sellerId == null || sellerId <= 0) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RegisterSellerScreen(
          phoneE164: phone,
          phoneVerified: true,
          kitchenSetupOnly: true,
          sellerId: sellerId,
        ),
      ),
    );

    if (!mounted) return;
    await _loadKycStatus();
  }

  SellerAccountProfile _profileFromKycResult(
    SellerPhoneCheckResult result,
    String phone,
  ) {
    final profile = result.sellerProfile;
    if (profile != null && profile.name.isNotEmpty) {
      return profile.copyWith(
        phoneE164: profile.phoneE164.isNotEmpty
            ? profile.phoneE164
            : (result.phoneE164 ?? phone),
      );
    }

    return SellerAccountProfile(
      id: result.sellerId ?? 0,
      name: result.sellerName ?? '',
      phoneE164: result.phoneE164 ?? phone,
      email: profile?.email ?? '',
      address: profile?.address ?? '',
      city: profile?.city ?? '',
      state: profile?.state ?? '',
      country: profile?.country ?? '',
    );
  }

  Future<void> _openAddress() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();
    if (phone == null || phone.isEmpty || !mounted) return;

    final updated = await Navigator.of(context).push<SellerAddressInfo>(
      MaterialPageRoute<SellerAddressInfo>(
        builder: (_) => SellerAddressScreen(
          phoneE164: phone,
        ),
      ),
    );

    if (!mounted) return;
    if (updated != null && _accountProfile != null) {
      setState(() {
        _accountProfile = _accountProfile!.copyWith(
          address: updated.address,
          city: updated.city,
          state: updated.state,
          country: updated.country,
          addressChangeStatus: updated.changeStatus,
        );
      });
      return;
    }
    await _loadKycStatus();
  }

  String get _addressSubtitle {
    final profile = _accountProfile;
    if (profile?.addressChangeStatus == 'pending') {
      return 'Change awaiting admin approval';
    }
    final parts = [
      profile?.city,
      profile?.state,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(', ');
    if (profile?.address.trim().isNotEmpty == true) {
      return profile!.address.trim();
    }
    return 'Add or update your address';
  }

  Future<void> _openEditProfile() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();
    if (phone == null || phone.isEmpty || !mounted) return;

    final updated = await Navigator.of(context).push<SellerAccountProfile>(
      MaterialPageRoute<SellerAccountProfile>(
        builder: (_) => SellerEditProfileScreen(
          phoneE164: phone,
          initialProfile: _accountProfile,
        ),
      ),
    );

    if (!mounted) return;
    if (updated != null) {
      setState(() => _accountProfile = updated);
      return;
    }
    await _loadKycStatus();
  }

  Future<void> _openNotifications() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();
    if (phone == null || phone.isEmpty || !mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SellerNotificationsScreen(phoneE164: phone),
      ),
    );
  }

  Future<void> _openHelpSupport() async {
    if (!mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SellerHelpSupportScreen(),
      ),
    );
  }

  Future<void> _openLegalDocument(String key) async {
    if (!mounted) return;

    SellerLegalDocument? initial;
    final legal = _legalDocuments;
    if (legal != null) {
      initial = key == 'privacy' ? legal.privacy : legal.terms;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(
          documentKey: key,
          initialDocument: initial,
        ),
      ),
    );
  }

  Future<void> _openWallet() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();
    if (phone == null || phone.isEmpty || !mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SellerWalletScreen(phoneE164: phone),
      ),
    );

    if (!mounted) return;
    await _loadKycStatus();
  }

  Future<void> _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        title: Text(
          'Sign out?',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
        content: Text(
          'You will need to verify your phone again to sign back in.',
          style: GoogleFonts.exo2(
            height: 1.4,
            color: AppColors.deepGreen.withValues(alpha: 0.75),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.exo2()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandPurple,
            ),
            child: Text('Sign out', style: GoogleFonts.exo2()),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    await SellerAuthNavigation.signOut();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const PhoneAuthScreen()),
      (route) => false,
    );
  }

  Color _kycStatusColor() {
    return switch (_documentKycStatus) {
      SellerDocumentKycStatusKind.approved => AppColors.sage,
      SellerDocumentKycStatusKind.pending => AppColors.orderPending,
      SellerDocumentKycStatusKind.rejected => AppColors.kitchenOff,
      _ => AppColors.deepGreen.withValues(alpha: 0.45),
    };
  }

  @override
  Widget build(BuildContext context) {
    final profile = _accountProfile;
    final displayName = profile?.name.isNotEmpty == true
        ? profile!.name
        : 'Seller account';
    final displayPhone = toDisplayE164(
      profile?.phoneE164.isNotEmpty == true
          ? profile!.phoneE164
          : (FirebaseAuth.instance.currentUser?.phoneNumber ?? ''),
    );
    final kycSubtitle = _loadingKyc
        ? 'Loading…'
        : _documentKycStatus.displayLabel;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              AppSystemUi.topInset(context, 8),
              24,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile',
                  style: GoogleFonts.exo2(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepGreen,
                  ),
                ),
                const SizedBox(height: 24),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: _loadingKyc ? null : _openEditProfile,
                    borderRadius: BorderRadius.circular(20),
                    child: Ink(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.brandPurple.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.brandPurple,
                                  AppColors.brandPurpleDeep,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: GoogleFonts.exo2(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.deepGreen,
                                  ),
                                ),
                                if (displayPhone.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    displayPhone,
                                    style: GoogleFonts.exo2(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.deepGreen.withValues(
                                        alpha: 0.65,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  'Tap to edit profile',
                                  style: GoogleFonts.exo2(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brandPurple.withValues(
                                      alpha: 0.75,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.deepGreen.withValues(alpha: 0.35),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _ProfileTile(
                  icon: Icons.verified_user_outlined,
                  title: 'KYC status',
                  subtitle: kycSubtitle,
                  trailing: _loadingKyc
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _KycStatusChip(
                          label: _documentKycStatus.displayLabel,
                          color: _documentKycStatus ==
                                  SellerDocumentKycStatusKind.pending
                              ? AppColors.bootstrapWarningText
                              : _kycStatusColor(),
                          backgroundColor: _documentKycStatus ==
                                  SellerDocumentKycStatusKind.pending
                              ? AppColors.bootstrapWarningBg
                              : null,
                        ),
                  onTap: _loadingKyc ? null : _onKycStatusTap,
                ),
                _ProfileTile(
                  icon: Icons.location_on_outlined,
                  title: 'Address',
                  subtitle: _loadingKyc ? 'Loading…' : _addressSubtitle,
                  trailing: _loadingKyc
                      ? null
                      : _accountProfile?.addressChangeStatus == 'pending'
                          ? _KycStatusChip(
                              label: 'Pending',
                              color: AppColors.bootstrapWarningText,
                              backgroundColor: AppColors.bootstrapWarningBg,
                            )
                          : null,
                  onTap: _loadingKyc ? null : _openAddress,
                ),
                if (_kitchenSetupPending)
                  _ProfileTile(
                    icon: Icons.storefront_outlined,
                    title: 'Kitchen profile',
                    subtitle: 'Set up your kitchen profile',
                    trailing: _KycStatusChip(
                      label: 'Set up',
                      color: AppColors.brandPurple,
                    ),
                    onTap: _loadingKyc ? null : _onKitchenSetupTap,
                  ),
                _ProfileTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Wallet',
                  subtitle: _loadingKyc
                      ? 'Loading…'
                      : _walletBalance != null
                          ? '${formatWalletAmount(_walletBalance!)} available'
                          : 'Earnings & withdrawals',
                  onTap: _loadingKyc ? null : _openWallet,
                ),
                _ProfileTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Alerts & updates you received',
                  onTap: _openNotifications,
                ),
                _ProfileTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & support',
                  subtitle: 'Contact Made by Maa',
                  onTap: _openHelpSupport,
                ),
                _ProfileTile(
                  icon: Icons.description_outlined,
                  title: 'Terms & Conditions',
                  subtitle: 'Seller agreement',
                  onTap: () => _openLegalDocument('terms'),
                ),
                _ProfileTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'How we use your data',
                  onTap: () => _openLegalDocument('privacy'),
                ),
                const SizedBox(height: 8),
                _ProfileTile(
                  icon: Icons.logout_rounded,
                  title: 'Sign out',
                  subtitle: 'Switch account',
                  isDestructive: true,
                  onTap: () => _signOut(context),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 130)),
      ],
    );
  }
}

class _KycStatusChip extends StatelessWidget {
  const _KycStatusChip({
    required this.label,
    required this.color,
    this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.exo2(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.isDestructive = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isDestructive;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color =
        isDestructive ? Colors.red.shade700 : AppColors.brandPurple;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: color.withValues(alpha: 0.85)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.exo2(
                          fontWeight: FontWeight.w700,
                          color: isDestructive
                              ? Colors.red.shade700
                              : AppColors.deepGreen,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.exo2(
                          fontSize: 12,
                          color: AppColors.deepGreen.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  trailing!,
                  if (onTap != null) const SizedBox(width: 4),
                ],
                if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.deepGreen.withValues(alpha: 0.3),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
