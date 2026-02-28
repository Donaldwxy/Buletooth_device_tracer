
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A simple data model for a location record
class LocationRecord {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  LocationRecord({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  // Serialization methods
  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
      };

  factory LocationRecord.fromJson(Map<String, dynamic> json) => LocationRecord(
        latitude: json['latitude'],
        longitude: json['longitude'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}

class LocationProvider with ChangeNotifier {
  final Location _location = Location();
  List<LocationRecord> _records = [];
  late SharedPreferences _prefs;

  List<LocationRecord> get records => _records;

  LocationProvider() {
    _loadRecords();
  }

  Future<void> recordLocation(bool use6DigitPrecision) async {
    try {
      final locationData = await _location.getLocation();
      final lat = _formatCoordinate(locationData.latitude, use6DigitPrecision);
      final lon = _formatCoordinate(locationData.longitude, use6DigitPrecision);

      final newRecord = LocationRecord(
        latitude: lat,
        longitude: lon,
        timestamp: DateTime.now(),
      );

      _records.insert(0, newRecord);
      if (_records.length > 10) {
        _records = _records.sublist(0, 10); // Keep only the latest 10
      }

      await _saveRecords();
      notifyListeners();
    } catch (e) {
      // Handle location errors (e.g., permissions denied)
      debugPrint('Error getting location: $e');
    }
  }

  double _formatCoordinate(double? coordinate, bool use6Digit) {
    if (coordinate == null) return 0.0;
    final factor = use6Digit ? 1e6 : 1e5;
    return (coordinate * factor).round() / factor;
  }

  // Persistence
  Future<void> _loadRecords() async {
    _prefs = await SharedPreferences.getInstance();
    final recordsJson = _prefs.getString('locationRecords');
    if (recordsJson != null) {
      final List<dynamic> decoded = jsonDecode(recordsJson);
      _records = decoded.map((item) => LocationRecord.fromJson(item)).toList();
      notifyListeners();
    }
  }

  Future<void> _saveRecords() async {
    final List<Map<String, dynamic>> recordsJson = _records.map((r) => r.toJson()).toList();
    await _prefs.setString('locationRecords', jsonEncode(recordsJson));
  }
}
