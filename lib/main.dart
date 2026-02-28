import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// --- Providers ---

class LocationRecord {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  LocationRecord(
      {required this.latitude,
      required this.longitude,
      required this.timestamp});

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
      };

  factory LocationRecord.fromJson(Map<String, dynamic> json) => LocationRecord(
        latitude: json['latitude'] as double,
        longitude: json['longitude'] as double,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class LocationProvider with ChangeNotifier {
  List<LocationRecord> _allRecords = [];
  List<LocationRecord> _filteredRecords = [];
  DateTime? _selectedDate;

  List<LocationRecord> get records => _filteredRecords;
  DateTime get selectedDate => _selectedDate ?? DateTime.now();

  LocationProvider() {
    loadRecords();
  }

  Future<void> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = prefs.getStringList('location_records') ?? [];
    _allRecords = recordsJson
        .map((json) => LocationRecord.fromJson(jsonDecode(json)))
        .toList();
    // Initially, show all records
    _filteredRecords = List.from(_allRecords);
    notifyListeners();
  }

  Future<void> addRecord(Position position) async {
    final record = LocationRecord(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
    );
    // 1. Add to in-memory list
    _allRecords.add(record);

    // 2. Incrementally update storage
    final prefs = await SharedPreferences.getInstance();
    final newRecordJson = jsonEncode(record.toJson());
    final existingRecords = prefs.getStringList('location_records') ?? [];
    existingRecords.add(newRecordJson);
    await prefs.setStringList('location_records', existingRecords);

    // 3. Update UI
    _filterRecordsByDate();
    notifyListeners();
  }

  Future<void> clearRecords() async {
    _allRecords.clear();
    _filteredRecords.clear();
    await _saveRecords(); // Overwrite with empty list
    notifyListeners();
  }

  // Full overwrite, only used for clearing records now
  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson =
        _allRecords.map((record) => jsonEncode(record.toJson())).toList();
    await prefs.setStringList('location_records', recordsJson);
  }

  void selectDate(DateTime? date) {
    _selectedDate = date;
    _filterRecordsByDate();
    notifyListeners();
  }

  void _filterRecordsByDate() {
    if (_selectedDate == null) {
      _filteredRecords = List.from(_allRecords);
    } else {
      final selected = _selectedDate!;
      _filteredRecords = _allRecords
          .where((record) =>
              record.timestamp.year == selected.year &&
              record.timestamp.month == selected.month &&
              record.timestamp.day == selected.day)
          .toList();
    }
  }
}

class SettingsProvider with ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('languageCode') ?? 'en';
    _locale = Locale(languageCode);
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', locale.languageCode);
    notifyListeners();
  }
}

// --- Widgets ---
class LocationCard extends StatelessWidget {
  final LocationRecord record;
  final int index;

  const LocationCard({super.key, required this.record, required this.index});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final dateFormat = DateFormat('MMM d, yyyy - hh:mm:ss a');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: ListTile(
        leading: CircleAvatar(
          child: Text('${index + 1}'),
        ),
        title: Text(dateFormat.format(record.timestamp)),
        subtitle: Text(settings.locale.languageCode == 'zh'
            ? '纬度: ${record.latitude.toStringAsFixed(4)}, 经度: ${record.longitude.toStringAsFixed(4)}'
            : 'Lat: ${record.latitude.toStringAsFixed(4)}, Lon: ${record.longitude.toStringAsFixed(4)}'),
        onTap: () => _launchMap(context, settings.locale),
      ),
    );
  }

  void _launchMap(BuildContext context, Locale locale) async {
    final lat = record.latitude;
    final lon = record.longitude;
    final Uri url;

    if (Platform.isAndroid && locale.languageCode == 'zh') {
        url = Uri.parse('androidamap://viewMap?sourceApplication=location_tracker&poiname=My Location&lat=$lat&lon=$lon&dev=1');
         if (await canLaunchUrl(url)) {
            await launchUrl(url);
        } else {
            // Fallback to Google Maps if Amap is not available
            final fallbackUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
            await launchUrl(fallbackUrl);
        }
    } else {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
      await launchUrl(url);
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();
    _startExitTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordLocation();
    });
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    super.dispose();
  }

  void _startExitTimer() {
    _exitTimer = Timer(const Duration(minutes: 5), () {
      if (mounted) {
        exit(0);
      }
    });
  }

  void _cancelExitTimer() {
    if (_exitTimer?.isActive ?? false) {
      _exitTimer!.cancel();
    }
  }

  Future<void> _recordLocation() async {
    final hasPermission = await _handleLocationPermission();
    if (!mounted) return;
    if (!hasPermission) return;

    try {
      final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if(mounted){
        Provider.of<LocationProvider>(context, listen: false).addRecord(position);
      }
    } catch (e) {
        if(mounted){
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
        }
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Location services are disabled. Please enable the services')));
      }
      return false;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if(mounted){
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')));
        }
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
       if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Location permissions are permanently denied, we cannot request permissions.')));
       }
      return false;
    }
    return true;
  }

  Future<void> _selectDate(BuildContext context) async {
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: locationProvider.selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    // Pass the picked date to the provider. It can be null.
    if(mounted){
      locationProvider.selectDate(picked);
    }
    
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Listener(
      onPointerDown: (_) => _cancelExitTimer(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(settingsProvider.locale.languageCode == 'zh'
              ? '位置历史'
              : 'Location History'),
          actions: [
            IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => _selectDate(context),
            ),
             // Add a button to clear the date filter
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Show all records',
              onPressed: () {
                locationProvider.selectDate(null);
              },
            ),
            IconButton(
              icon: const Icon(Icons.language),
              onPressed: () {
                final newLocale = settingsProvider.locale.languageCode == 'en'
                    ? const Locale('zh')
                    : const Locale('en');
                settingsProvider.setLocale(newLocale);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                Provider.of<LocationProvider>(context, listen: false)
                    .clearRecords();
              },
            ),
          ],
        ),
        body: locationProvider.records.isEmpty
            ? Center(
                child: Text(settingsProvider.locale.languageCode == 'zh'
                    ? '没有记录'
                    : 'No records yet'))
            : ListView.builder(
                itemCount: locationProvider.records.length,
                itemBuilder: (context, index) {
                  return LocationCard(
                    record: locationProvider.records[index],
                    index: index,
                  );
                },
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: _recordLocation,
          child: const Icon(Icons.add_location),
        ),
      ),
    );
  }
}

// --- Main App ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // It's better to create all providers before the app runs
  final settingsProvider = SettingsProvider();
  await settingsProvider.loadSettings();
  final locationProvider = LocationProvider();
  // No need to await loadRecords, it will notify listeners when done.

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: locationProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      title: 'Location Tracker',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      locale: settings.locale,
      localizationsDelegates: const [
        // Add required delegates if you have them, e.g., for intl
      ],
      supportedLocales: const [Locale('en', ''), Locale('zh', '')],
      home: const HomeScreen(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final baseTheme = ThemeData(brightness: brightness);
    final textColor = brightness == Brightness.light ? Colors.black : Colors.white;

    return baseTheme.copyWith(
      textTheme:
          GoogleFonts.latoTextTheme(baseTheme.textTheme).apply(bodyColor: textColor),
      appBarTheme: AppBarTheme(
        titleTextStyle: GoogleFonts.oswald(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
