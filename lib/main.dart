
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'src/providers/location_provider.dart';
import 'src/providers/settings_provider.dart';
import 'src/home_screen.dart';

void main() async { // Make main async
  WidgetsFlutterBinding.ensureInitialized();

  // Create an instance of SettingsProvider
  final settingsProvider = SettingsProvider();
  // Load settings before running the app
  await settingsProvider.loadSettings();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        // Use the pre-loaded instance of SettingsProvider
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
      themeMode: ThemeMode.system, // Or bind to a setting
      locale: settings.locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      // No localizationsDelegates needed for this simple setup
      home: const HomeScreen(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final baseTheme = ThemeData(brightness: brightness);
    final textColor = brightness == Brightness.light ? Colors.black : Colors.white;

    return baseTheme.copyWith(
      textTheme: GoogleFonts.latoTextTheme(baseTheme.textTheme).apply(bodyColor: textColor),
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
