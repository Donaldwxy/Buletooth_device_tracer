import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';


// --- Providers ---

class LocationRecord {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  LocationRecord(
      {required this.latitude, required this.longitude, required this.timestamp});

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
    _filterRecordsByDate(null);
    notifyListeners();
  }

  Future<void> addRecord(Position position) async {
    final record = LocationRecord(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
    );
    _allRecords.add(record);
    _updateStorageIncrementally(record);
    _filterRecordsByDate(_selectedDate);
    notifyListeners();
  }

  Future<void> _updateStorageIncrementally(LocationRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = prefs.getStringList('location_records') ?? [];
    recordsJson.add(jsonEncode(record.toJson()));
    await prefs.setStringList('location_records', recordsJson);
  }

  Future<void> clearRecords() async {
    _allRecords.clear();
    _filteredRecords.clear();
    await _saveRecords();
    notifyListeners();
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('location_records', []);
  }

  void selectDate(DateTime? date) {
    _filterRecordsByDate(date);
    notifyListeners();
  }

  void _filterRecordsByDate(DateTime? date) {
    _selectedDate = date;
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
  bool _inactivityTimeoutEnabled = true;
  bool _recordOnForegroundEnabled = true;
  int _gpsPrecision = 6;

  Locale get locale => _locale;
  bool get inactivityTimeoutEnabled => _inactivityTimeoutEnabled;
  bool get recordOnForegroundEnabled => _recordOnForegroundEnabled;
  int get gpsPrecision => _gpsPrecision;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _locale = Locale(prefs.getString('languageCode') ?? 'en');
    _inactivityTimeoutEnabled =
        prefs.getBool('inactivityTimeoutEnabled') ?? true;
    _recordOnForegroundEnabled =
        prefs.getBool('recordOnForegroundEnabled') ?? true;
    _gpsPrecision = prefs.getInt('gpsPrecision') ?? 6;
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', locale.languageCode);
    notifyListeners();
  }

  Future<void> setInactivityTimeoutEnabled(bool enabled) async {
    _inactivityTimeoutEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('inactivityTimeoutEnabled', enabled);
    notifyListeners();
  }

  Future<void> setRecordOnForegroundEnabled(bool enabled) async {
    _recordOnForegroundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('recordOnForegroundEnabled', enabled);
    notifyListeners();
  }

  Future<void> setGpsPrecision(int precision) async {
    _gpsPrecision = precision;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('gpsPrecision', precision);
    notifyListeners();
  }
}

// --- Widgets ---

class AppLifecycleObserver extends WidgetsBindingObserver {
  final Function onResumed;

  AppLifecycleObserver({required this.onResumed});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}

class LocationRecordCard extends StatefulWidget {
  final LocationRecord record;
  final int index;

  const LocationRecordCard({super.key, required this.record, required this.index});

  @override
  State<LocationRecordCard> createState() => _LocationRecordCardState();
}

class _LocationRecordCardState extends State<LocationRecordCard> {
  late Future<String> _bluetoothStatusFuture;

  @override
  void initState() {
    super.initState();
    _bluetoothStatusFuture = _getBluetoothStatus();
  }

  Future<String> _getBluetoothStatus() async {
    // 1. 检查蓝牙开关
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      return 'Bluetooth Off';
    }

    // 2. 权限检查
    var status = await Permission.bluetoothConnect.request();
    if (!status.isGranted) {
      return 'Bluetooth permission denied.';
    }

    try {
      // 💡 修复关键：添加括号 () 并传入参数 []
      // systemDevices 现在是一个方法，必须调用它
      var systemDevices = await FlutterBluePlus.systemDevices([]); 

      if (systemDevices.isEmpty) {
        return 'No connected devices';
      }

      final deviceNames = systemDevices
          .map((d) => d.platformName.isNotEmpty ? d.platformName : d.remoteId.toString())
          .toList();

      return 'Connected: ${deviceNames.join(', ')}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  void _launchMap(BuildContext context, Locale locale) async {
    final lat = widget.record.latitude;
    final lon = widget.record.longitude;

    if (Platform.isAndroid && locale.languageCode == 'zh') {
      try {
        final poiname = Uri.encodeComponent('我的位置');
        final String amapDataString =
            'androidamap://viewMap?sourceApplication=device_tracer&poiname=$poiname&lat=$lat&lon=$lon&dev=1';

        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          category: 'android.intent.category.DEFAULT',
          data: amapDataString,
          package: 'com.autonavi.minimap',
        );
        await intent.launch();
      } catch (e) {
        // Fallback to browser if Amap is not installed or launch fails
        final fallbackUrl =
            Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      }
    } else {
      final url =
          Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final dateFormat =
        DateFormat('MMM d, yyyy - hh:mm:ss a', settings.locale.languageCode);
    final precision = settings.gpsPrecision;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: ListTile(
        leading: CircleAvatar(
          child: Text('${widget.index + 1}'),
        ),
        title: Text(dateFormat.format(widget.record.timestamp)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(settings.locale.languageCode == 'zh'
                ? '纬度: ${widget.record.latitude.toStringAsFixed(precision)}, 经度: ${widget.record.longitude.toStringAsFixed(precision)}'
                : 'Lat: ${widget.record.latitude.toStringAsFixed(precision)}, Lon: ${widget.record.longitude.toStringAsFixed(precision)}'),
            FutureBuilder<String>(
              future: _bluetoothStatusFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Text('Checking Bluetooth...', style: TextStyle(color: Colors.grey));
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red));
                } else {
                  return Text(snapshot.data ?? 'Unknown status', style: TextStyle(color: Theme.of(context).colorScheme.secondary));
                }
              },
            ),
          ],
        ),
        onTap: () => _launchMap(context, settings.locale),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  Timer? _exitTimer;
  bool _isExitTimerArmed = false;
  late AppLifecycleObserver _lifecycleObserver;

  @override
  void initState() {
    super.initState();
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    if (settingsProvider.inactivityTimeoutEnabled) {
      _armAndStartExitTimer();
    }

    _lifecycleObserver = AppLifecycleObserver(
      onResumed: () {
        if (Provider.of<SettingsProvider>(context, listen: false)
            .recordOnForegroundEnabled) {
          _recordLocation();
        }
      },
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recordLocation();
    });
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  void _armAndStartExitTimer() {
    _isExitTimerArmed = true;
    _exitTimer?.cancel();
    _exitTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        exit(0);
      }
    });
  }

  void _disarmAndCancelExitTimer() {
    _exitTimer?.cancel();
    _isExitTimerArmed = false;
  }

  void _handleUserInteraction([_]) {
    if (_isExitTimerArmed) {
      _armAndStartExitTimer();
    }
  }

  Future<void> _recordLocation() async {
    final hasPermission = await _handleLocationPermission();
    if (!mounted || !hasPermission) return;

    try {
      final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (mounted) {
        Provider.of<LocationProvider>(context, listen: false).addRecord(position);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error getting location: $e')));
      }
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied')));
        }
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Location permissions are permanently denied, we cannot request permissions.')));
      }
      return false;
    }
    return true;
  }

  Future<void> _selectDate(BuildContext context) async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: locationProvider.selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: settingsProvider.locale,
    );

    if (picked != null) {
      locationProvider.selectDate(picked);
    } else {
      locationProvider.selectDate(null);
    }
  }

  void _showSettingsModal(BuildContext context) {

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return Wrap(
              children: [
                SwitchListTile(
                    title: Text(settings.locale.languageCode == 'zh'
                        ? '高精度GPS (6位小数)'
                        : 'High Precision GPS (6 decimals)'),
                    value: settings.gpsPrecision == 6,
                    onChanged: (bool value) {
                      settings.setGpsPrecision(value ? 6 : 5);
                    }),
                SwitchListTile(
                  title: Text(settings.locale.languageCode == 'zh'
                      ? '10秒无操作自动退出'
                      : 'Auto-exit after 10s inactivity'),
                  value: settings.inactivityTimeoutEnabled,
                  onChanged: (bool value) {
                    settings.setInactivityTimeoutEnabled(value);
                    if (value) {
                      _armAndStartExitTimer();
                    } else {
                      _disarmAndCancelExitTimer();
                    }
                  },
                ),
                SwitchListTile(
                  title: Text(settings.locale.languageCode == 'zh'
                      ? '回到前台自动记录'
                      : 'Record location on app resume'),
                  value: settings.recordOnForegroundEnabled,
                  onChanged: (bool value) {
                    settings.setRecordOnForegroundEnabled(value);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Listener(
      onPointerDown: _handleUserInteraction,
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
              icon: const Icon(Icons.settings),
              onPressed: () => _showSettingsModal(context),
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
                  final records = locationProvider.records;
                  final recordIndex = records.length - 1 - index;
                  return LocationRecordCard(
                    record: records[recordIndex],
                    index: recordIndex,
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

  final settingsProvider = SettingsProvider();
  await settingsProvider.loadSettings();
  final locationProvider = LocationProvider();

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
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', ''), Locale('zh', '')],
      home: const HomeScreen(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final baseTheme = ThemeData(brightness: brightness);
    final textColor =
        brightness == Brightness.light ? Colors.black : Colors.white;

    return baseTheme.copyWith(
      textTheme: GoogleFonts.latoTextTheme(baseTheme.textTheme)
          .apply(bodyColor: textColor),
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
