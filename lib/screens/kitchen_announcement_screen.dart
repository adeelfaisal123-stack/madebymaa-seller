import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/seller_kitchen_announcement.dart';
import '../seller_session_prefs.dart';
import '../services/optica2_api.dart';
import '../theme/app_colors.dart';
import '../widgets/app_toast.dart';

/// Edit kitchen announcement title and description.
class KitchenAnnouncementScreen extends StatefulWidget {
  const KitchenAnnouncementScreen({
    super.key,
    required this.phoneE164,
    this.initialAnnouncement,
  });

  final String phoneE164;
  final SellerKitchenAnnouncement? initialAnnouncement;

  @override
  State<KitchenAnnouncementScreen> createState() =>
      _KitchenAnnouncementScreenState();
}

class _KitchenAnnouncementScreenState extends State<KitchenAnnouncementScreen> {
  final _api = Optica2Api();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  KitchenAnnouncementType _type = KitchenAnnouncementType.general;

  @override
  void initState() {
    super.initState();
    if (widget.initialAnnouncement != null) {
      _apply(widget.initialAnnouncement!);
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _api.close();
    super.dispose();
  }

  void _apply(SellerKitchenAnnouncement announcement) {
    _titleController.text = announcement.title ?? '';
    _descriptionController.text = announcement.description ?? '';
    _type = announcement.type ?? KitchenAnnouncementType.general;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final announcement = await _api.fetchKitchenAnnouncement(
        phoneE164: widget.phoneE164,
        sellerId: sellerId,
      );
      if (!mounted) return;
      setState(() {
        _apply(announcement);
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

  Future<void> _openTypePicker() async {
    if (_saving) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Announcement type',
                          style: GoogleFonts.exo2(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepGreen,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                        color: AppColors.deepGreen,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose how customers should read this update.',
                      style: GoogleFonts.exo2(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.deepGreen.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ),
                ...KitchenAnnouncementType.values.map((type) {
                  final selected = _type == type;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () {
                          setState(() => _type = type);
                          Navigator.pop(sheetContext);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? AppColors.brandPurple.withValues(alpha: 0.45)
                                  : AppColors.deepGreen.withValues(alpha: 0.1),
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.brandPurple
                                          .withValues(alpha: 0.12)
                                      : AppColors.cream,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  type.icon,
                                  color: selected
                                      ? AppColors.brandPurple
                                      : AppColors.deepGreen
                                          .withValues(alpha: 0.55),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  type.label,
                                  style: GoogleFonts.exo2(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.deepGreen,
                                  ),
                                ),
                              ),
                              if (selected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.brandPurple,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _fieldDecoration(String label) {
    final borderColor = AppColors.deepGreen.withValues(alpha: 0.15);
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.exo2(
        color: AppColors.deepGreen.withValues(alpha: 0.6),
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.brandPurple, width: 1.6),
      ),
    );
  }

  Widget _typeSelectField() {
    return InputDecorator(
      decoration: _fieldDecoration('Announcement type'),
      child: InkWell(
        onTap: _saving ? null : _openTypePicker,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.brandPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _type.icon,
                size: 20,
                color: AppColors.brandPurple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _type.label,
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepGreen,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _saving
                  ? AppColors.deepGreen.withValues(alpha: 0.25)
                  : AppColors.brandPurple,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isNotEmpty && title.length < 2) {
      AppToast.warning(context, 'Enter an announcement title.');
      return;
    }
    if (title.isEmpty && description.isNotEmpty) {
      AppToast.warning(context, 'Add a title for your announcement.');
      return;
    }

    setState(() => _saving = true);
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final updated = await _api.updateKitchenAnnouncement(
        phoneE164: widget.phoneE164,
        title: title.isEmpty ? null : title,
        description: description.isEmpty ? null : description,
        type: title.isEmpty ? null : _type,
        sellerId: sellerId,
      );
      if (!mounted) return;
      AppToast.success(context, 'Announcement updated.');
      Navigator.pop(context, updated);
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.danger(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.danger(context, 'Could not save. Try again.');
    }
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
          'Announcement',
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
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Share offers or updates with customers on your kitchen page.',
                    style: GoogleFonts.exo2(
                      fontSize: 14,
                      color: AppColors.deepGreen.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _typeSelectField(),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _titleController,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 120,
                    style: GoogleFonts.exo2(color: AppColors.deepGreen),
                    decoration: _fieldDecoration('Title'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 6,
                    minLines: 4,
                    maxLength: 2000,
                    style: GoogleFonts.exo2(color: AppColors.deepGreen),
                    decoration: _fieldDecoration('Description').copyWith(
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Save announcement',
                            style: GoogleFonts.exo2(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
