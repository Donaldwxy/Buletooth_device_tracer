
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import '../providers/settings_provider.dart';

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
        subtitle: Text('Lat: ${record.latitude}, Lon: ${record.longitude}'),
        onTap: () => _launchMap(context, settings.locale),
      ),
    );
  }

  void _launchMap(BuildContext context, Locale locale) {
    final lat = record.latitude;
    final lon = record.longitude;

    if (locale.languageCode == 'zh') {
      final intent = AndroidIntent(
        action: 'action_view',
        data: Uri.encodeFull('androidamap://viewMap?sourceApplication=location_tracker&poiname=My Location&lat=$lat&lon=$lon&dev=1'),
      );
      intent.launch();
    } else {
      final googleMapsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
      launchUrl(googleMapsUri);
    }
  }
}
