import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/map_pin_selection.dart';
import '../models/seller_address_info.dart';
import '../models/seller_zone.dart';
import '../seller_session_prefs.dart';
import '../services/google_maps_config_service.dart';
import '../services/optica2_api.dart';
import '../theme/app_colors.dart';
import '../utils/geo_polygon.dart';
import '../utils/reverse_geocoding.dart';
import '../widgets/app_toast.dart';
import '../widgets/kyc_zone_map_picker.dart';

class SellerAddressScreen extends StatefulWidget {
  const SellerAddressScreen({
    super.key,
    required this.phoneE164,
    this.initialInfo,
  });

  final String phoneE164;
  final SellerAddressInfo? initialInfo;

  @override
  State<SellerAddressScreen> createState() => _SellerAddressScreenState();
}

class _SellerAddressScreenState extends State<SellerAddressScreen> {
  final _api = Optica2Api();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _countryController;
  bool _loading = true;
  bool _saving = false;
  bool _geocoding = false;
  bool _zonesLoading = false;
  String? _mapsError;
  SellerAddressInfo? _info;
  SellerMapsConfig _maps = GoogleMapsConfigService.maps;
  List<SellerZone> _zones = [];
  int? _selectedZoneId;
  LatLng? _pin;
  int _geocodeGeneration = 0;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _countryController = TextEditingController(text: 'IN');

    final initial = widget.initialInfo;
    if (initial != null) {
      _info = initial;
      _applyToForm(initial);
      _applyLocationFromInfo(initial);
      _loading = false;
      _bootstrapMap(initial);
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _api.close();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _applyToForm(SellerAddressInfo info) {
    final source = info.isPending && info.pending != null
        ? info.pending!
        : SellerAddressSnapshot(
            address: info.address,
            city: info.city,
            state: info.state,
            country: info.country,
            formatted: info.formatted,
          );

    _addressController.text = source.address;
    _cityController.text = source.city;
    _stateController.text = source.state;
    _countryController.text =
        source.country.isNotEmpty ? source.country : 'IN';
  }

  Future<void> _loadMapsConfig({bool refresh = true}) async {
    setState(() => _mapsError = null);

    try {
      final config = await GoogleMapsConfigService.loadFromAdmin(
        api: _api,
        refresh: refresh,
      );
      if (!mounted) return;
      setState(() {
        _maps = config;
        if (config.apiKey.isEmpty) {
          _mapsError =
              'Google Maps API key is not set. Add it in Optica2 admin → System settings → Google Maps API key.';
        }
      });
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      setState(() => _mapsError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mapsError =
            'Could not load Google Maps settings from the admin panel.';
      });
    }
  }

  void _applyLocationFromInfo(SellerAddressInfo info) {
    final source = info.isPending && info.pending != null
        ? info.pending!
        : SellerAddressSnapshot(
            address: info.address,
            city: info.city,
            state: info.state,
            country: info.country,
            zoneId: info.zoneId,
            zoneName: info.zoneName,
            latitude: info.latitude,
            longitude: info.longitude,
            formatted: info.formatted,
          );

    _selectedZoneId = source.zoneId;
    if (source.latitude != null && source.longitude != null) {
      _pin = LatLng(source.latitude!, source.longitude!);
    }
  }

  Future<void> _loadZones() async {
    if (_zones.isNotEmpty || _zonesLoading) return;
    setState(() => _zonesLoading = true);
    try {
      final response = await _api.fetchSellerZones();
      if (!mounted) return;
      GoogleMapsConfigService.applyFromZones(response.maps);
      setState(() {
        _zones = response.zones;
        if (_maps.apiKey.isEmpty && response.maps.apiKey.isNotEmpty) {
          _maps = response.maps;
        }
        _zonesLoading = false;
        if (_selectedZoneId == null && _zones.length == 1) {
          _applyZoneSelection(_zones.first);
        } else if (_selectedZoneId != null && _pin == null) {
          final zone = _zones
              .where((z) => z.id == _selectedZoneId)
              .cast<SellerZone?>()
              .firstOrNull;
          if (zone != null) {
            _pin = zone.center ?? _maps.defaultCenter;
          }
        }
      });
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      setState(() => _zonesLoading = false);
      AppToast.danger(context, e.message);
    } catch (_) {
      if (mounted) setState(() => _zonesLoading = false);
    }
  }

  void _applyZoneSelection(SellerZone zone) {
    final nextPin = zone.center ?? _maps.defaultCenter;
    setState(() {
      _selectedZoneId = zone.id;
      _pin = nextPin;
    });
    _applyReverseGeocode(nextPin);
  }

  Future<void> _bootstrapMap(SellerAddressInfo info) async {
    await Future.wait([
      _loadMapsConfig(),
      _loadZones(),
    ]);
    if (!mounted || _mapsError != null || !_mapsReady) return;
    await _resolveInitialPin(info);
  }

  bool get _mapsReady => _maps.apiKey.isNotEmpty;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final results = await Future.wait<Object>([
        _api.fetchSellerAddress(
          phoneE164: widget.phoneE164,
          sellerId: sellerId,
        ),
        GoogleMapsConfigService.loadFromAdmin(api: _api, refresh: true),
        _api.fetchSellerZones(),
      ]);
      if (!mounted) return;
      final info = results[0] as SellerAddressInfo;
      final maps = results[1] as SellerMapsConfig;
      final zonesResponse = results[2] as SellerZonesResponse;
      GoogleMapsConfigService.applyFromZones(zonesResponse.maps);
      setState(() {
        _info = info;
        _applyToForm(info);
        _applyLocationFromInfo(info);
        _maps = maps.apiKey.isNotEmpty ? maps : zonesResponse.maps;
        _zones = zonesResponse.zones;
        _mapsError = _maps.apiKey.isEmpty
            ? 'Google Maps API key is not set. Add it in Optica2 admin → System settings → Google Maps API key.'
            : null;
        _loading = false;
        _zonesLoading = false;
        if (_selectedZoneId == null && _zones.length == 1) {
          _applyZoneSelection(_zones.first);
        }
      });
      if (_mapsReady) {
        await _resolveInitialPin(info);
      }
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _zonesLoading = false;
        _mapsError ??= e.message;
      });
      AppToast.danger(context, e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _zonesLoading = false;
        });
      }
    }
  }

  Future<void> _resolveInitialPin(SellerAddressInfo info) async {
    if (_pin != null) return;

    final source = info.isPending && info.pending != null
        ? info.pending!
        : SellerAddressSnapshot(
            address: info.address,
            city: info.city,
            state: info.state,
            country: info.country,
            zoneId: info.zoneId,
            zoneName: info.zoneName,
            latitude: info.latitude,
            longitude: info.longitude,
            formatted: info.formatted,
          );

    LatLng? pin;
    if (source.latitude != null && source.longitude != null) {
      pin = LatLng(source.latitude!, source.longitude!);
    } else if (source.formatted.isNotEmpty) {
      pin = await geocodeAddressQuery(source.formatted);
    } else {
      final parts = [
        source.address,
        source.city,
        source.state,
        source.country,
      ].where((part) => part.trim().isNotEmpty).join(', ');
      if (parts.isNotEmpty) {
        pin = await geocodeAddressQuery(parts);
      }
    }

    pin ??= await _currentLocationPin();
    if (_selectedZoneId != null && pin != null) {
      final zone = _zones.where((z) => z.id == _selectedZoneId).firstOrNull;
      if (zone != null && !GeoPolygon.containsLatLng(zone.polygon, pin)) {
        pin = zone.center ?? pin;
      }
    }

    if (!mounted) return;
    setState(() => _pin = pin);

    final hasExistingAddress = source.address.trim().isNotEmpty ||
        source.city.trim().isNotEmpty;
    if (pin != null && !hasExistingAddress && !info.isPending) {
      await _applyReverseGeocode(pin);
    }
  }

  Future<LatLng?> _currentLocationPin() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_info?.isPending == true) return;

    final pin = await _currentLocationPin();
    if (pin == null) {
      if (mounted) {
        AppToast.warning(
          context,
          'Could not detect your location. Move the map to place the pin instead.',
        );
      }
      return;
    }

    final zone = _zones.where((z) => z.id == _selectedZoneId).firstOrNull;
    if (zone != null && !GeoPolygon.containsLatLng(zone.polygon, pin)) {
      if (mounted) {
        AppToast.warning(
          context,
          'Your location is outside the selected zone. Pick a zone or move the map.',
        );
      }
      return;
    }

    setState(() => _pin = pin);
    await _applyReverseGeocode(pin);
  }

  Future<void> _onLocationPicked(MapPinSelection selection) async {
    if (_info?.isPending == true) return;

    final generation = ++_geocodeGeneration;
    final hadPin = _pin != null;
    _pin = selection.pin;
    debugPrint(
      'Address pin dropped: ${selection.pin.latitude}, ${selection.pin.longitude}',
    );

    await _applyReverseGeocodeForGeneration(selection.pin, generation);

    if (!hadPin && mounted) setState(() {});
  }

  void _applyParsedAddress(ParsedAddress parsed) {
    setState(() {
      _addressController.text = parsed.address;
      _cityController.text = parsed.city;
      _stateController.text = parsed.state;
      _countryController.text =
          parsed.country.isNotEmpty ? parsed.country : 'IN';
      _geocoding = false;
    });
  }

  Future<void> _applyReverseGeocode(LatLng pin) async {
    await _applyReverseGeocodeForGeneration(pin, ++_geocodeGeneration);
  }

  Future<void> _applyReverseGeocodeForGeneration(
    LatLng pin,
    int generation,
  ) async {
    if (!mounted) return;
    setState(() => _geocoding = true);

    final parsed = await reverseGeocodeLocation(
      pin,
      googleMapsApiKey: _maps.apiKey,
    );
    if (!mounted || generation != _geocodeGeneration) return;

    if (parsed == null || !parsed.hasAnyField) {
      debugPrint('Address reverse geocode returned no fields.');
      if (!mounted || generation != _geocodeGeneration) return;
      setState(() => _geocoding = false);
      AppToast.warning(
        context,
        'Could not read address for this location. Enter details manually.',
      );
      return;
    }

    if (!mounted || generation != _geocodeGeneration) return;
    debugPrint(
      'Address reverse geocode fields: '
      '${parsed.address} | ${parsed.city} | ${parsed.state} | ${parsed.country}',
    );
    _applyParsedAddress(parsed);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_info?.canSubmitChange != true) {
      AppToast.warning(
        context,
        'An address change is already awaiting admin approval.',
      );
      return;
    }
    if (_selectedZoneId == null) {
      AppToast.warning(context, 'Select a delivery zone.');
      return;
    }
    if (_pin == null) {
      AppToast.warning(context, 'Pin your kitchen on the map.');
      return;
    }

    final zone = _zones.where((z) => z.id == _selectedZoneId).firstOrNull;
    if (zone != null && !GeoPolygon.containsLatLng(zone.polygon, _pin!)) {
      AppToast.warning(context, 'Pin must be inside the selected zone.');
      return;
    }

    setState(() => _saving = true);
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final updated = await _api.submitSellerAddress(
        phoneE164: widget.phoneE164,
        sellerId: sellerId,
        address: _addressController.text,
        city: _cityController.text,
        state: _stateController.text,
        country: _countryController.text,
        zoneId: _selectedZoneId!,
        latitude: _pin!.latitude,
        longitude: _pin!.longitude,
      );
      if (!mounted) return;
      setState(() {
        _info = updated;
        _applyToForm(updated);
      });
      AppToast.success(
        context,
        updated.isPending
            ? 'Address change submitted for admin approval.'
            : 'Address saved.',
      );
      Navigator.pop(context, updated);
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.danger(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.danger(context, 'Could not save address.');
    }
  }

  InputDecoration _fieldDecoration(String hint) {
    final border = AppColors.brandPurple.withValues(alpha: 0.28);
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.exo2(
        color: AppColors.deepGreen.withValues(alpha: 0.35),
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.brandPurple, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    bool readOnly = false,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w700,
            color: AppColors.deepGreen.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          validator: validator,
          textCapitalization: textCapitalization,
          style: GoogleFonts.exo2(
            color: readOnly
                ? AppColors.deepGreen.withValues(alpha: 0.55)
                : AppColors.deepGreen,
          ),
          decoration: _fieldDecoration(hint).copyWith(
            fillColor: readOnly ? AppColors.cream : Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _zoneMapSection({required bool readOnly}) {
    if (_zonesLoading) {
      return ColoredBox(
        color: AppColors.brandPurple.withValues(alpha: 0.08),
        child: SizedBox(
          height: 320,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.brandPurple),
                const SizedBox(height: 12),
                Text(
                  'Loading delivery zones…',
                  style: GoogleFonts.exo2(
                    fontSize: 13,
                    color: AppColors.deepGreen.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_zones.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.brandPurple.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'No delivery zones are active yet. Ask admin to create a zone in the kitchen panel.',
          style: GoogleFonts.exo2(
            fontSize: 13,
            height: 1.45,
            color: AppColors.deepGreen.withValues(alpha: 0.75),
          ),
        ),
      );
    }

    if (!_mapsReady) {
      return ColoredBox(
        color: AppColors.brandPurple.withValues(alpha: 0.08),
        child: SizedBox(
          height: 320,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _mapsError ??
                        'Map unavailable. Set the Google Maps API key in Optica2 admin → System settings.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.exo2(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.deepGreen.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => _loadMapsConfig(refresh: true),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      'Retry',
                      style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final picker = KycZoneMapPicker(
      zones: _zones,
      maps: _maps,
      selectedZoneId: _selectedZoneId,
      pin: _pin,
      interactive: !readOnly,
      resolveAddress: false,
      scrollController: readOnly ? null : _scrollController,
      onZoneSelected: _applyZoneSelection,
      onLocationPicked: readOnly ? null : _onLocationPicked,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Delivery zone',
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepGreen.withValues(alpha: 0.8),
                ),
              ),
            ),
            if (!readOnly && _mapsReady)
              TextButton.icon(
                onPressed: _geocoding ? null : _useCurrentLocation,
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: Text(
                  'My location',
                  style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandPurple,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        picker,
        if (readOnly) ...[
          if (_info?.isPending == true &&
              _info?.pending?.zoneName != null &&
              _info!.pending!.zoneName!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Requested zone: ${_info!.pending!.zoneName}',
                style: GoogleFonts.exo2(
                  fontSize: 12,
                  color: AppColors.deepGreen.withValues(alpha: 0.65),
                ),
              ),
            )
          else if (_info?.zoneName != null && _info!.zoneName!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Current zone: ${_info!.zoneName}',
                style: GoogleFonts.exo2(
                  fontSize: 12,
                  color: AppColors.deepGreen.withValues(alpha: 0.65),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _statusBanner(SellerAddressInfo info) {
    if (info.isPending) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bootstrapWarningBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.bootstrapWarningBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  color: AppColors.bootstrapWarningText,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Awaiting admin approval',
                  style: GoogleFonts.exo2(
                    fontWeight: FontWeight.w800,
                    color: AppColors.bootstrapWarningText,
                  ),
                ),
              ],
            ),
            if (info.pending != null) ...[
              const SizedBox(height: 8),
              Text(
                'Requested: ${info.pending!.formatted}',
                style: GoogleFonts.exo2(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.bootstrapWarningText.withValues(alpha: 0.9),
                ),
              ),
              if (info.pending!.zoneName != null &&
                  info.pending!.zoneName!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Zone: ${info.pending!.zoneName}',
                  style: GoogleFonts.exo2(
                    fontSize: 12,
                    color:
                        AppColors.bootstrapWarningText.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
            if (info.formatted.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Current: ${info.formatted}',
                style: GoogleFonts.exo2(
                  fontSize: 12,
                  color: AppColors.bootstrapWarningText.withValues(alpha: 0.75),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (info.isRejected) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.kitchenOff.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.kitchenOff.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: AppColors.kitchenOff.withValues(alpha: 0.85),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Your last address change was rejected. You can submit a new address below.',
                style: GoogleFonts.exo2(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.deepGreen.withValues(alpha: 0.78),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (info.hasAddress) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.brandPurple.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.brandPurple.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          'Address changes need admin approval after your first address is saved.',
          style: GoogleFonts.exo2(
            fontSize: 13,
            height: 1.45,
            color: AppColors.deepGreen.withValues(alpha: 0.72),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final readOnly = info?.isPending == true;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.deepGreen),
        title: Text(
          'Address',
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
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (info != null) ...[
                      _statusBanner(info),
                      const SizedBox(height: 16),
                    ],
                    _zoneMapSection(readOnly: readOnly),
                    if (_geocoding) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.brandPurple,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Updating address from map…',
                            style: GoogleFonts.exo2(
                              fontSize: 12,
                              color:
                                  AppColors.deepGreen.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    _field(
                      controller: _addressController,
                      label: 'Street address',
                      hint: 'House no., street, area',
                      readOnly: readOnly,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _cityController,
                      label: 'City',
                      hint: 'City',
                      readOnly: readOnly,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _stateController,
                      label: 'State',
                      hint: 'State',
                      readOnly: readOnly,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _countryController,
                      label: 'Country code',
                      hint: 'IN',
                      readOnly: readOnly,
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) {
                        final value = v?.trim().toUpperCase() ?? '';
                        if (value.length != 2) {
                          return 'Use 2-letter country code';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    if (!readOnly)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: _saving || _geocoding ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.brandPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  info?.hasAddress == true
                                      ? 'Submit for approval'
                                      : 'Save address',
                                  style: GoogleFonts.exo2(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
