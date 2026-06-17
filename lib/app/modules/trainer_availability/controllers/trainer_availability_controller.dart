import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrainerAvailabilityController extends ChangeNotifier {
  // Days of the week with their availability status and times
  final Map<String, Map<String, dynamic>> availability = {
    'Mon': {'active': false, 'startTime': '09:00', 'endTime': '17:00'},
    'Tue': {'active': false, 'startTime': '09:00', 'endTime': '17:00'},
    'Wed': {'active': false, 'startTime': '09:00', 'endTime': '17:00'},
    'Thu': {'active': false, 'startTime': '09:00', 'endTime': '17:00'},
    'Fri': {'active': false, 'startTime': '09:00', 'endTime': '17:00'},
    'Sat': {'active': false, 'startTime': '10:00', 'endTime': '16:00'},
    'Sun': {'active': false, 'startTime': '10:00', 'endTime': '16:00'},
  };

  int get activeCount =>
      availability.values.where((day) => day['active'] == true).length;

  void toggleDay(String day) {
    availability[day]!['active'] = !(availability[day]!['active'] as bool);
    notifyListeners();
  }

  void setStartTime(String day, String time) {
    availability[day]!['startTime'] = time;
    notifyListeners();
  }

  void setEndTime(String day, String time) {
    availability[day]!['endTime'] = time;
    notifyListeners();
  }

  void saveAvailability({required void Function(String title, String message) onNotify}) {
    onNotify('Success', 'Availability saved! $activeCount days active.');
  }
}

final trainerAvailabilityProvider = ChangeNotifierProvider((ref) => TrainerAvailabilityController());
