
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:android_intent_plus/android_intent.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '设备追踪器',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LocationTracker(),
    );
  }
}

class LocationTracker extends StatefulWidget {
  const LocationTracker({super.key});

  @override
  State<LocationTracker> createState() => _LocationTrackerState();
}

class _LocationTrackerState extends State<LocationTracker> {
  LocationPermission? _permission;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  final List<Position> _locations = [];
  Timer? _timer;
  String _currentTime = '';
  String _currentDate = '';
  String _currentWeekDay = '';

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _startTracking();
    _updateTime();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    final locale = Platform.localeName;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      setState(() {
        _currentTime = DateFormat.Hms(locale).format(now);
        _currentDate = DateFormat.yMMMMd(locale).format(now);
        _currentWeekDay = DateFormat.EEEE(locale).format(now);
      });
    });
  }

  Future<void> _checkPermission() async {
    final permission = await Geolocator.checkPermission();
    setState(() {
      _permission = permission;
    });
    if (_permission == LocationPermission.denied ||
        _permission == LocationPermission.deniedForever) {
      _requestPermission();
    }
  }

  Future<void> _requestPermission() async {
    final permission = await Geolocator.requestPermission();
    setState(() {
      _permission = permission;
    });
  }

  void _startTracking() {
    if (_permission == LocationPermission.always ||
        _permission == LocationPermission.whileInUse) {
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      );
      _positionStream =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen((Position position) {
        setState(() {
          _currentPosition = position;
          _locations.add(position);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设备追踪器'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _currentDate,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              _currentWeekDay,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              _currentTime,
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            if (_permission == null)
              const CircularProgressIndicator()
            else if (_permission == LocationPermission.denied)
              Column(
                children: [
                  const Text('定位权限被拒绝，请授予权限以使用本应用。'),
                  ElevatedButton(
                    onPressed: _requestPermission,
                    child: const Text('授予权限'),
                  ),
                ],
              )
            else if (_permission == LocationPermission.deniedForever)
              const Text('定位权限被永久拒绝，请在系统设置中开启。')
            else if (_currentPosition == null)
              const CircularProgressIndicator()
            else
              Card(
                elevation: 4,
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInfoRow(
                          Icons.location_on,
                          '纬度',
                          _currentPosition!.latitude.toStringAsFixed(6)),
                      _buildInfoRow(
                          Icons.location_on,
                          '经度',
                          _currentPosition!.longitude.toStringAsFixed(6)),
                      _buildInfoRow(Icons.speed, '速度',
                          '${(_currentPosition!.speed * 3.6).toStringAsFixed(2)} km/h'),
                      _buildInfoRow(
                          Icons.explore,
                          '方向',
                          _currentPosition!.heading.toStringAsFixed(2)),
                      _buildInfoRow(
                          Icons.height,
                          '海拔',
                          '${_currentPosition!.altitude.toStringAsFixed(2)} m'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.map),
                        label: const Text("在地图中打开"),
                        onPressed: () => _openMap(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                            locale),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text('记录点数量: ${_locations.length}'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(value),
        ],
      ),
    );
  }

  void _openMap(double lat, double lon, Locale locale) async {
    if (!mounted) return;

    if (_currentPosition != null) {
      if (Platform.isAndroid && locale.languageCode == 'zh') {
        try {
          final poiname = Uri.encodeComponent('我的位置');
          final intent = AndroidIntent(
            action: 'android.intent.action.VIEW',
            category: 'android.intent.category.DEFAULT',
            data: Uri.parse(
                    'androidamap://viewMap?sourceApplication=device_tracer&poiname=$poiname&lat=$lat&lon=$lon&dev=1')
                .toString(),
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
  }
}
