
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/location_provider.dart';
import 'providers/settings_provider.dart';
import 'widgets/location_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetInactivityTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (settings.recordOnForeground) {
        Provider.of<LocationProvider>(context, listen: false).recordLocation(settings.use6DigitPrecision);
      }
    }
  }

  void _resetInactivityTimer() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.exitOnInactive) return;

    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 10), () {
      SystemNavigator.pop(); // Close the app
    });
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Listener(
      onPointerDown: (_) => _resetInactivityTimer(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            settingsProvider.locale.languageCode == 'en' ? 'Location History' : '位置历史',
            style: GoogleFonts.oswald(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: Icon(settingsProvider.use6DigitPrecision ? Icons.looks_6 : Icons.looks_5),
              tooltip: 'Toggle GPS Precision',
              onPressed: () => settingsProvider.togglePrecision(),
            ),
            IconButton(
              icon: const Icon(Icons.calendar_today),
              tooltip: 'View History',
              onPressed: () { /* Calendar view not yet implemented */ },
            ),
            IconButton(
              icon: const Icon(Icons.language),
              tooltip: 'Toggle Language',
              onPressed: () => settingsProvider.toggleLocale(),
            ),
          ],
        ),
        body: Column(
          children: [
            SwitchListTile(
              title: Text(settingsProvider.locale.languageCode == 'en' ? 'Exit on Inactivity' : '无操作时退出'),
              subtitle: Text(settingsProvider.locale.languageCode == 'en' ? 'Close app after 10s of inactivity' : '10秒无操作后关闭应用'),
              value: settingsProvider.exitOnInactive,
              onChanged: (value) => settingsProvider.toggleExitOnInactive(),
            ),
            SwitchListTile(
              title: Text(settingsProvider.locale.languageCode == 'en' ? 'Record on Foreground' : '进入前台时记录'),
              subtitle: Text(settingsProvider.locale.languageCode == 'en' ? 'Record location when app is opened' : '打开应用时记录位置'),
              value: settingsProvider.recordOnForeground,
              onChanged: (value) => settingsProvider.toggleRecordOnForeground(),
            ),
            const Divider(),
            Expanded(
              child: locationProvider.records.isEmpty
                  ? Center(child: Text(settingsProvider.locale.languageCode == 'en' ? 'No records yet.' : '暂无记录'))
                  : ListView.builder(
                      itemCount: locationProvider.records.length,
                      itemBuilder: (context, index) => LocationCard(
                        record: locationProvider.records[index],
                        index: index,
                      ),
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => locationProvider.recordLocation(settingsProvider.use6DigitPrecision),
          child: const Icon(Icons.add_location),
        ),
      ),
    );
  }
}
