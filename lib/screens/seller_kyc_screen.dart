import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/seller_zone.dart';
import '../services/google_maps_config_service.dart';
import '../services/optica2_api.dart';
import '../services/seller_auth_navigation.dart';
import '../theme/app_colors.dart';
import '../utils/geo_polygon.dart';
import '../widgets/app_toast.dart';
import '../widgets/kyc_zone_map_picker.dart';
import '../utils/app_system_ui.dart';

/// Delivery zone pin after registration (no document uploads).
class SellerKycScreen extends StatefulWidget {
  const SellerKycScreen({
    super.key,
    required this.sellerId,
    required this.phoneE164,
    this.resumeToHomeOnComplete = false,
  });

  final int sellerId;
  final String phoneE164;
  final bool resumeToHomeOnComplete;

  @override
  State<SellerKycScreen> createState() => _SellerKycScreenState();
}

class _SellerKycScreenState extends State<SellerKycScreen> {
  final _optica2 = Optica2Api();

  List<SellerZone> _zones = [];
  SellerMapsConfig _maps = const SellerMapsConfig(
    apiKey: '',
    defaultLat: 20.5937,
    defaultLng: 78.9629,
  );
  bool _zonesLoading = false;
  int? _selectedZoneId;
  LatLng? _pin;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadZones());
  }

  @override
  void dispose() {
    _optica2.close();
    super.dispose();
  }

  Future<void> _loadZones() async {
    if (_zones.isNotEmpty || _zonesLoading) return;
    setState(() => _zonesLoading = true);
    try {
      await GoogleMapsConfigService.ensureLoaded(api: _optica2);
      final response = await _optica2.fetchSellerZones();
      if (!mounted) return;
      GoogleMapsConfigService.applyFromZones(response.maps);
      setState(() {
        _zones = response.zones;
        _maps = GoogleMapsConfigService.maps.apiKey.isNotEmpty
            ? GoogleMapsConfigService.maps
            : response.maps;
        _zonesLoading = false;
        if (_zones.length == 1 && _selectedZoneId == null) {
          _applyZoneSelection(_zones.first);
        }
      });
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      setState(() => _zonesLoading = false);
      AppToast.danger(context, e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _zonesLoading = false);
      AppToast.danger(context, '$e');
    }
  }

  void _applyZoneSelection(SellerZone zone) {
    setState(() {
      _selectedZoneId = zone.id;
      _pin = zone.center ?? _maps.defaultCenter;
    });
  }

  bool _validate() {
    if (_selectedZoneId == null) {
      AppToast.warning(context, 'Select a delivery zone.');
      return false;
    }
    if (_pin == null) {
      AppToast.warning(context, 'Pin your kitchen on the map.');
      return false;
    }
    final zone = _zones.where((z) => z.id == _selectedZoneId).firstOrNull;
    if (zone != null && !GeoPolygon.containsLatLng(zone.polygon, _pin!)) {
      AppToast.warning(context, 'Pin must be inside the selected zone.');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _submitting = true);
    var finishedFlow = false;

    try {
      final message = await _optica2.completeSellerKyc(
        sellerId: widget.sellerId,
        phoneE164: widget.phoneE164,
        zoneId: _selectedZoneId!,
        latitude: _pin!.latitude,
        longitude: _pin!.longitude,
      );
      if (!mounted) return;

      finishedFlow = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.resumeToHomeOnComplete) {
          SellerAuthNavigation.openHome(context);
          return;
        }
        SellerAuthNavigation.openKycPending(
          context,
          sellerId: widget.sellerId,
          phoneE164: widget.phoneE164,
          message: message,
        );
      });
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      AppToast.danger(context, e.message);
    } catch (e) {
      if (!mounted) return;
      AppToast.danger(context, '$e');
    } finally {
      if (mounted && !finishedFlow) {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _zoneContent() {
    if (_zonesLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandPurple),
      );
    }

    if (_zones.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No delivery zones are active yet. Ask admin to create a zone in the kitchen panel.',
            textAlign: TextAlign.center,
            style: GoogleFonts.exo2(
              height: 1.45,
              color: AppColors.deepGreen.withValues(alpha: 0.75),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: KycZoneMapPicker(
        zones: _zones,
        maps: _maps,
        selectedZoneId: _selectedZoneId,
        pin: _pin,
        onZoneSelected: _applyZoneSelection,
        onPinChanged: (pos) => setState(() => _pin = pos),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: AppSystemUi.topInset(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 24, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  color: AppColors.deepGreen,
                  onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    'Delivery zone',
                    style: GoogleFonts.exo2(
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepGreen,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pin your kitchen',
                  style: GoogleFonts.exo2(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose your zone, then move the map so the fixed pin sits on your kitchen.',
                  style: GoogleFonts.exo2(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.deepGreen.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: _zoneContent()),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              AppSystemUi.bottomInset(context, 24),
            ),
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Submit for approval',
                      style: GoogleFonts.exo2(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
