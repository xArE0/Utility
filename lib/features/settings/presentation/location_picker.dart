import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/models/weather_location.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/system_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../utils/api_services.dart';

/// Bottom sheet to search for a place or switch between saved ones. Picking one applies right away
/// (weather, sunrise/sunset, AQI and the home screen widget follow it).
Future<void> showLocationPicker(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LocationPickerSheet(),
  );
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet();

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  /// Bumped per search so a slow earlier response can't overwrite a newer one.
  int _searchId = 0;
  bool _searching = false;
  bool _searchFailed = false;
  List<WeatherLocation>? _results;
  bool _locating = false;
  String? _locateError;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String value) async {
    _debounce?.cancel();
    final query = value.trim();
    final id = ++_searchId;
    if (query.length < 2) {
      setState(() {
        _searching = false;
        _searchFailed = false;
        _results = null;
      });
      return;
    }
    setState(() => _searching = true);
    final results = await ApiServices.searchLocations(query);
    if (!mounted || id != _searchId) return;
    setState(() {
      _searching = false;
      _searchFailed = results == null;
      _results = results ?? [];
    });
  }

  /// One coarse fix; asks for the location permission the first time.
  Future<void> _useDeviceLocation() async {
    setState(() {
      _locating = true;
      _locateError = null;
    });
    String? error;
    try {
      final status = await Permission.locationWhenInUse.request();
      if (status.isPermanentlyDenied) {
        error = 'Location permission is off — allow it in app settings';
        await openAppSettings();
      } else if (!status.isGranted && !status.isLimited) {
        error = 'Location permission denied';
      } else {
        final fix = await SystemService.currentLocation();
        if (!mounted) return;
        await _select(WeatherLocation(
          name: 'My location',
          detail: '${fix.latitude.toStringAsFixed(2)}, ${fix.longitude.toStringAsFixed(2)}',
          latitude: fix.latitude,
          longitude: fix.longitude,
          isDevice: true,
        ));
        return;
      }
    } on PlatformException catch (e) {
      error = switch (e.code) {
        'LOCATION_OFF' => 'Turn on location in quick settings and try again',
        'TIMEOUT' => "Couldn't get a fix — try again",
        _ => 'Location unavailable',
      };
    } catch (_) {
      error = 'Location unavailable';
    }
    if (mounted) {
      setState(() {
        _locating = false;
        _locateError = error;
      });
    }
  }

  Future<void> _select(WeatherLocation location) async {
    await SettingsService.instance.selectLocation(location);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: AppColors.slate800.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(top: BorderSide(color: AppColors.slate600, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.slate500,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Weather Location', style: AppTypography.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Weather, sunrise/sunset and air quality are shown for this place.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.slate400),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              onSubmitted: _search,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search city or place',
                prefixIcon: const Icon(Icons.search, color: AppColors.govBlue),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.slate900.withValues(alpha: 0.6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListenableBuilder(
                listenable: SettingsService.instance,
                builder: (context, _) => ListView(
                  shrinkWrap: true,
                  children: _results != null ? _buildResults() : _buildSaved(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildResults() {
    if (_results!.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              _searchFailed ? "Couldn't search — check your connection" : 'No places found',
              style: AppTypography.bodySmall.copyWith(color: AppColors.slate400),
            ),
          ),
        ),
      ];
    }
    final activeKey = SettingsService.instance.location.key;
    return _results!
        .map((l) => _buildTile(l, active: l.key == activeKey, icon: Icons.place_outlined))
        .toList();
  }

  List<Widget> _buildSaved() {
    final settings = SettingsService.instance;
    return [
      ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 4, right: 0),
        leading: _locating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: Padding(
                  padding: EdgeInsets.all(3),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Icon(Icons.my_location, color: AppColors.govBlue),
        title: const Text(
          'Use my location',
          style: TextStyle(color: AppColors.slate200, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _locateError ?? 'One approximate fix (~1 km), only when you tap',
          style: AppTypography.bodySmall.copyWith(
              color: _locateError != null ? AppColors.warning : AppColors.slate500),
        ),
        onTap: _locating ? null : _useDeviceLocation,
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
        child: Text(
          'SAVED',
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.govBlue,
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      ...settings.savedLocations.map((l) {
        final active = l.key == settings.location.key;
        return _buildTile(
          l,
          active: active,
          icon: l.isDevice ? Icons.my_location : Icons.bookmark_outline,
          trailing: active
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppColors.slate500),
                  tooltip: 'Remove',
                  onPressed: () => settings.removeLocation(l),
                ),
        );
      }),
    ];
  }

  Widget _buildTile(WeatherLocation l,
      {required bool active, required IconData icon, Widget? trailing}) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 4, right: 0),
      leading: Icon(active ? Icons.check_circle : icon,
          color: active ? AppColors.govGreen : AppColors.slate400),
      title: Text(
        l.name,
        style: TextStyle(
          color: AppColors.slate200,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: l.detail.isEmpty
          ? null
          : Text(l.detail, style: AppTypography.bodySmall.copyWith(color: AppColors.slate500)),
      trailing: trailing,
      onTap: () => _select(l),
    );
  }
}
