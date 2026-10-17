import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/seller_kitchen_announcement.dart';
import '../../models/seller_kitchen_cuisines.dart';
import '../../models/seller_kitchen_profile.dart';
import '../../models/seller_training_video.dart';
import '../../seller_auth_prefs.dart';
import '../../seller_session_prefs.dart';
import '../../services/optica2_api.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_system_ui.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/seller_training_stories_strip.dart';
import '../add_dish_screen.dart';
import '../kitchen_addons_screen.dart';
import '../kitchen_coupons_screen.dart';
import '../kitchen_announcement_screen.dart';
import '../kitchen_cuisines_screen.dart';
import '../kitchen_profile_screen.dart';
import '../kitchen_schedule_screen.dart';

/// Center hub tab — kitchen quick actions.
class SellerKitchenTab extends StatefulWidget {
  const SellerKitchenTab({
    super.key,
    this.onViewMenu,
  });

  /// Switches to Menu tab to see dishes after adding.
  final VoidCallback? onViewMenu;

  @override
  State<SellerKitchenTab> createState() => SellerKitchenTabState();
}

class SellerKitchenTabState extends State<SellerKitchenTab> {
  final _api = Optica2Api();
  SellerKitchenProfile? _profile;
  bool _profileLoading = true;
  SellerKitchenAnnouncement? _announcement;
  bool _announcementLoading = true;
  SellerKitchenCuisines? _cuisines;
  bool _cuisinesLoading = true;
  List<SellerTrainingVideo> _trainingVideos = const [];
  bool _trainingVideosLoading = true;

  @override
  void initState() {
    super.initState();
    reloadProfile();
    reloadAnnouncement();
    reloadCuisines();
    reloadTrainingVideos();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> reloadProfile() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        setState(() {
          _profile = null;
          _profileLoading = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _profileLoading = true);

    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final profile = await _api.fetchKitchenProfile(
        phoneE164: phone,
        sellerId: sellerId,
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _profileLoading = false;
      });
    } on Optica2ApiException catch (_) {
      if (!mounted) return;
      setState(() => _profileLoading = false);
    } catch (_) {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  Future<void> reloadAnnouncement() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        setState(() {
          _announcement = null;
          _announcementLoading = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _announcementLoading = true);

    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final announcement = await _api.fetchKitchenAnnouncement(
        phoneE164: phone,
        sellerId: sellerId,
      );
      if (!mounted) return;
      setState(() {
        _announcement = announcement;
        _announcementLoading = false;
      });
    } on Optica2ApiException catch (_) {
      if (!mounted) return;
      setState(() => _announcementLoading = false);
    } catch (_) {
      if (mounted) setState(() => _announcementLoading = false);
    }
  }

  Future<void> reloadCuisines() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        setState(() {
          _cuisines = null;
          _cuisinesLoading = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _cuisinesLoading = true);

    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final cuisines = await _api.fetchKitchenCuisines(
        phoneE164: phone,
        sellerId: sellerId,
      );
      if (!mounted) return;
      setState(() {
        _cuisines = cuisines;
        _cuisinesLoading = false;
      });
    } on Optica2ApiException catch (_) {
      if (!mounted) return;
      setState(() => _cuisinesLoading = false);
    } catch (_) {
      if (mounted) setState(() => _cuisinesLoading = false);
    }
  }

  Future<void> reloadTrainingVideos() async {
    if (mounted) setState(() => _trainingVideosLoading = true);

    try {
      final videos = await _api.fetchTrainingVideos();
      if (!mounted) return;
      setState(() {
        _trainingVideos = videos;
        _trainingVideosLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _trainingVideos = const [];
          _trainingVideosLoading = false;
        });
      }
    }
  }

  Future<void> _openCuisines(BuildContext context) async {
    final phone =
        await _phoneOrWarn(context, 'Sign in to manage cuisines.');
    if (phone == null || !context.mounted) return;

    final updated = await Navigator.of(context).push<SellerKitchenCuisines>(
      MaterialPageRoute<SellerKitchenCuisines>(
        builder: (_) => KitchenCuisinesScreen(
          phoneE164: phone,
          initial: _cuisines,
        ),
      ),
    );

    if (!context.mounted) return;
    if (updated != null) {
      setState(() => _cuisines = updated);
    } else {
      await reloadCuisines();
    }
  }

  Future<String?> _phoneOrWarn(BuildContext context, String message) async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();
    if (phone == null || phone.isEmpty) {
      if (context.mounted) {
        AppToast.warning(context, message);
      }
      return null;
    }
    return phone;
  }

  Future<void> _openAnnouncement(BuildContext context) async {
    final phone =
        await _phoneOrWarn(context, 'Sign in to edit your announcement.');
    if (phone == null || !context.mounted) return;

    final updated = await Navigator.of(context).push<SellerKitchenAnnouncement>(
      MaterialPageRoute<SellerKitchenAnnouncement>(
        builder: (_) => KitchenAnnouncementScreen(
          phoneE164: phone,
          initialAnnouncement: _announcement,
        ),
      ),
    );

    if (!context.mounted) return;
    if (updated != null) {
      setState(() => _announcement = updated);
    } else {
      await reloadAnnouncement();
    }
  }

  Future<void> _openKitchenProfile(BuildContext context) async {
    final phone = await _phoneOrWarn(context, 'Sign in to edit kitchen profile.');
    if (phone == null || !context.mounted) return;

    final updated = await Navigator.of(context).push<SellerKitchenProfile>(
      MaterialPageRoute<SellerKitchenProfile>(
        builder: (_) => KitchenProfileScreen(
          phoneE164: phone,
          initialProfile: _profile,
        ),
      ),
    );

    if (!context.mounted) return;
    if (updated != null) {
      setState(() => _profile = updated);
    } else {
      await reloadProfile();
    }
  }

  Future<void> _openAddDish(BuildContext context) async {
    final phone = await _phoneOrWarn(context, 'Sign in to add dishes.');
    if (phone == null || !context.mounted) return;

    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddDishScreen(phoneE164: phone),
      ),
    );

    if (!context.mounted) return;
    if (added == true) {
      AppToast.success(context, 'Dish added. See it on your Menu tab.');
      widget.onViewMenu?.call();
    }
  }

  Future<void> _openAddons(BuildContext context) async {
    final phone = await _phoneOrWarn(context, 'Sign in to manage add-ons.');
    if (phone == null || !context.mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => KitchenAddonsScreen(phoneE164: phone),
      ),
    );
  }

  Future<void> _openCoupons(BuildContext context) async {
    final phone = await _phoneOrWarn(context, 'Sign in to manage coupons.');
    if (phone == null || !context.mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => KitchenCouponsScreen(phoneE164: phone),
      ),
    );
  }

  Future<void> _openKitchenSchedule(BuildContext context) async {
    final phone =
        await _phoneOrWarn(context, 'Sign in to manage kitchen hours.');
    if (phone == null || !context.mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => KitchenScheduleScreen(phoneE164: phone),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              AppSystemUi.topInset(context, 8),
              24,
              20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SellerTrainingStoriesStrip(
                  videos: _trainingVideos,
                  loading: _trainingVideosLoading,
                ),
                if (_trainingVideos.isNotEmpty || _trainingVideosLoading)
                  const SizedBox(height: 16),
                Text(
                  'Kitchen',
                  style: GoogleFonts.exo2(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage your stall from one place.',
                  style: GoogleFonts.exo2(
                    fontSize: 14,
                    color: AppColors.deepGreen.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 20),
                _KitchenProfileCard(
                  loading: _profileLoading,
                  profile: _profile,
                  onTap: () => _openKitchenProfile(context),
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.restaurant_outlined,
                  title: 'Cuisines',
                  subtitle: _cuisinesLoading
                      ? 'Loading…'
                      : (_cuisines?.selectedLabel ?? 'Choose your cuisines'),
                  color: AppColors.brandPurpleDeep,
                  onTap: () => _openCuisines(context),
                ),
                _ActionCard(
                  icon: Icons.add_circle_outline_rounded,
                  title: 'Add new dish',
                  subtitle: 'Photo, price & availability',
                  color: AppColors.brandPurple,
                  onTap: () => _openAddDish(context),
                ),
                _ActionCard(
                  icon: Icons.toggle_on_outlined,
                  title: 'Open / close kitchen',
                  subtitle: 'Set open days & pause orders today',
                  color: AppColors.sage,
                  onTap: () => _openKitchenSchedule(context),
                ),
                _ActionCard(
                  icon: Icons.add_box_outlined,
                  title: 'Add-on',
                  subtitle: 'Extras like Cookie ₹50',
                  color: AppColors.terracotta,
                  onTap: () => _openAddons(context),
                ),
                _ActionCard(
                  icon: Icons.confirmation_number_outlined,
                  title: 'Coupons',
                  subtitle: 'Percent or flat off · enable anytime',
                  color: AppColors.amberGlow,
                  onTap: () => _openCoupons(context),
                ),
                _AnnouncementCard(
                  loading: _announcementLoading,
                  announcement: _announcement,
                  onTap: () => _openAnnouncement(context),
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

class _KitchenProfileCard extends StatelessWidget {
  const _KitchenProfileCard({
    required this.loading,
    required this.profile,
    this.onTap,
  });

  final bool loading;
  final SellerKitchenProfile? profile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.brandPurple;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              _ProfileAvatar(loading: loading, profile: profile),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kitchen Profile',
                      style: GoogleFonts.exo2(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (loading)
                      Text(
                        'Loading…',
                        style: GoogleFonts.exo2(
                          fontSize: 12,
                          color: AppColors.deepGreen.withValues(alpha: 0.55),
                        ),
                      )
                    else ...[
                      Text(
                        profile?.name ?? 'Update name & logo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.exo2(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepGreen.withValues(alpha: 0.75),
                        ),
                      ),
                      if (profile != null &&
                          profile!.deliveryTimeLabel != null &&
                          profile!.deliveryTimeLabel!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          profile!.deliveryTimeLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.exo2(
                            fontSize: 11,
                            color: AppColors.deepGreen.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                      if (profile != null && !profile!.instantDeliveryEnabled) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Instant delivery off',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.exo2(
                            fontSize: 11,
                            color: AppColors.deepGreen.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.deepGreen.withValues(alpha: 0.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.loading,
    this.profile,
  });

  final bool loading;
  final SellerKitchenProfile? profile;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.brandPurple;

    if (loading) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent.withValues(alpha: 0.08),
          border: Border.all(color: accent, width: 2),
        ),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: accent,
          ),
        ),
      );
    }

    final url = profile?.logoUrl;
    if (url != null && url.isNotEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: accent, width: 2),
        ),
        child: ClipOval(
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, e, s) => _placeholderIcon(accent),
          ),
        ),
      );
    }

    return _placeholderIcon(accent);
  }

  Widget _placeholderIcon(Color accent) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 2),
        color: accent.withValues(alpha: 0.08),
      ),
      child: Icon(Icons.storefront_rounded, color: accent, size: 26),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.loading,
    required this.announcement,
    this.onTap,
  });

  final bool loading;
  final SellerKitchenAnnouncement? announcement;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.sage;

    String subtitle;
    if (loading) {
      subtitle = 'Loading…';
    } else {
      final title = announcement?.title?.trim();
      final typeLabel = announcement?.displayTypeLabel;
      if (title != null && title.isNotEmpty) {
        subtitle = typeLabel != null && typeLabel.isNotEmpty
            ? '$typeLabel · $title'
            : title;
      } else {
        subtitle = 'Update type, title & description';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 2),
                    color: accent.withValues(alpha: 0.08),
                  ),
                  child: Icon(
                    Icons.campaign_outlined,
                    color: accent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Announcement',
                        style: GoogleFonts.exo2(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepGreen,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.exo2(
                          fontSize: 12,
                          color: AppColors.deepGreen.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.deepGreen.withValues(alpha: 0.25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                    color: color.withValues(alpha: 0.08),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.exo2(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepGreen,
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
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.deepGreen.withValues(alpha: 0.25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
