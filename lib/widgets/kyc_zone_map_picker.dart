import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/map_pin_selection.dart';
import '../models/seller_zone.dart';
import '../services/google_maps_config_service.dart';
import '../theme/app_colors.dart';
import 'kyc_zone_google_map_flutter.dart';
import 'map_touch_scroll_lock.dart';

/// Zone list + map with polygon overlay and kitchen pin (API key from admin).
class KycZoneMapPicker extends StatelessWidget {
  const KycZoneMapPicker({
    super.key,
    required this.zones,
    required this.maps,
    required this.selectedZoneId,
    required this.pin,
    required this.onZoneSelected,
    this.onPinChanged,
    this.onLocationPicked,
    this.resolveAddress = false,
    this.interactive = true,
    this.scrollController,
  });

  final List<SellerZone> zones;
  final SellerMapsConfig maps;
  final int? selectedZoneId;
  final LatLng? pin;
  final ValueChanged<SellerZone> onZoneSelected;
  final ValueChanged<LatLng>? onPinChanged;
  final ValueChanged<MapPinSelection>? onLocationPicked;
  final bool resolveAddress;
  final bool interactive;
  final ScrollController? scrollController;

  SellerMapsConfig get _effectiveMaps {
    if (maps.apiKey.isNotEmpty) return maps;
    return GoogleMapsConfigService.maps;
  }

  SellerZone? _selected() {
    if (selectedZoneId == null) return null;
    for (final z in zones) {
      if (z.id == selectedZoneId) return z;
    }
    return null;
  }

  LatLng _initialTarget(SellerZone? zone, SellerMapsConfig config) {
    return pin ?? zone?.center ?? config.defaultCenter;
  }

  @override
  Widget build(BuildContext context) {
    final config = _effectiveMaps;
    final zone = _selected();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: zones.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final z = zones[index];
              final selected = z.id == selectedZoneId;
              return ChoiceChip(
                label: Text(
                  z.name,
                  style: GoogleFonts.exo2(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: selected ? Colors.white : AppColors.deepGreen,
                  ),
                ),
                selected: selected,
                onSelected: interactive ? (_) => onZoneSelected(z) : null,
                selectedColor: AppColors.brandPurple,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: selected
                      ? AppColors.brandPurple
                      : AppColors.brandPurple.withValues(alpha: 0.25),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 260,
            child: _buildMap(config, zone),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          selectedZoneId == null
              ? 'Select a delivery zone above.'
              : 'Move the map to place the fixed pin inside the purple zone — address, city, state and country fill automatically.',
          style: GoogleFonts.exo2(
            fontSize: 12,
            height: 1.4,
            color: AppColors.deepGreen.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }

  Widget _buildMap(SellerMapsConfig config, SellerZone? zone) {
    final mapsReady = config.apiKey.isNotEmpty;
    if (!mapsReady || zone == null) {
      return ColoredBox(
        color: AppColors.brandPurple.withValues(alpha: 0.08),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              mapsReady
                  ? 'Select a delivery zone above to show the map.'
                  : 'Map unavailable. Add your Google Maps API key in Optica2 admin → System settings.',
              textAlign: TextAlign.center,
              style: GoogleFonts.exo2(
                fontSize: 13,
                height: 1.45,
                color: AppColors.deepGreen.withValues(alpha: 0.75),
              ),
            ),
          ),
        ),
      );
    }

    final map = KycZoneGoogleMapFlutter(
      key: ValueKey('zone_map_${zone.id}'),
      zones: zones,
      zone: zone,
      initialCenter: _initialTarget(zone, config),
      pin: pin,
      interactive: interactive,
      onPinChanged: onPinChanged ?? (_) {},
      onLocationPicked: onLocationPicked,
    );

    if (interactive && scrollController != null) {
      return MapTouchScrollLock(
        scrollController: scrollController!,
        child: map,
      );
    }

    return map;
  }
}
