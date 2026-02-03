import 'package:dio/dio.dart';
import '../api.dart';
import '../models/event_model.dart';

class CalendarService {
  CalendarService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;
  final Dio _dio;

  /// Backend:
  /// GET /events/by-day/:date
  /// where :date should be YYYY-MM-DD (recommended)
  Future<List<EventDto>> fetchEventsByDay(String dateYyyyMmDd) async {
    final res = await _dio.get('/events/by-day/$dateYyyyMmDd');

    final data = res.data;
    if (data is List) {
      return data
          .map((e) => EventDto.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return <EventDto>[];
  }

  /// Backend:
  /// GET /events/by-month/:date
  /// You can pass YYYY-MM-DD (use first day of month)
  Future<List<EventDto>> fetchEventsByMonth(String dateYyyyMmDd) async {
    final res = await _dio.get('/events/by-month/$dateYyyyMmDd');

    final data = res.data;
    if (data is List) {
      return data
          .map((e) => EventDto.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return <EventDto>[];
  }

  /// Backend:
  /// GET /events
  Future<List<EventDto>> fetchAllEvents() async {
    final res = await _dio.get('/events');

    final data = res.data;
    if (data is List) {
      return data
          .map((e) => EventDto.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return <EventDto>[];
  }

  /// Backend:
  /// POST /events
  ///
  /// IMPORTANT:
  /// Your backend CreateEventDto currently requires description to be non-empty,
  /// so we enforce a fallback string.
  Future<void> createEvent({
    required String title,
    String? description,
    required String dateTimeIso, // ISO string (UTC recommended)
  }) async {
    final safeTitle = title.trim();
    final safeDescription =
        (description != null && description.trim().isNotEmpty)
            ? description.trim()
            : 'No description';

    await _dio.post('/events', data: {
      'title': safeTitle,
      'description': safeDescription,
      'date': dateTimeIso,
    });
  }
}
