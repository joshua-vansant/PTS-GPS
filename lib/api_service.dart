import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer';
import 'package:google_directions_api/google_directions_api.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:math' as math;


class APIService {
    Future<dynamic> fetchData() async {
    final response = await http.get(Uri.parse(
        'https://api.init.st/data/v1/events/latest?accessKey=ist_rg6P7BFsuN8Ekew6hKsE5t9QoMEp2KZN&bucketKey=jmvs_pts_tracker'));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      // log(jsonResponse.toString());
      return jsonResponse;
    } else {
      throw Exception('Failed to load data');
    }
  }

    Future<String> getETA(Point origin, Point destination, TravelMode travelMode, [List<Point>? waypoints]) async {
      final cacheManager = DefaultCacheManager();
      final originStr = '${origin.coordinates.lat}, ${origin.coordinates.lng}';
      final destinationStr = '${destination.coordinates.lat}, ${destination.coordinates.lng}';
      final cacheKey = '$originStr-$destinationStr';
      final fileStream = cacheManager.getFileFromCache(cacheKey);
      return fileStream.then((fileInfo) async {
        if (fileInfo != null && await fileInfo.file.exists()) {
          log('using a cached eta!! *GOOD NEWS!*');
          final file = fileInfo.file;
          final cachedValue = await file.readAsString();
          return cachedValue;
        } else {
          DirectionsService.init(dotenv.env['DIRECTIONS_API_KEY'] ?? 'Failed to load Directions API Key');
          final directionsService = DirectionsService();
          final request = DirectionsRequest(
            origin: originStr,
            destination: destinationStr,
            travelMode: travelMode,
            waypoints: waypoints?.map((waypoint) => DirectionsWaypoint(
              location: '${waypoint.coordinates.lat}, ${waypoint.coordinates.lng}',
            )).toList(),
          );

        final Completer<String> completer = Completer<String>();
        directionsService.route(request, (DirectionsResult response, DirectionsStatus? status) async {
          if (status == DirectionsStatus.ok) {
            final route = response.routes!.first;
            final duration = route.legs!.first.duration;
            final eta = '${duration!.value.toString()}';
            final file = await cacheManager.putFile(cacheKey, Uint8List.fromList(eta.codeUnits));
            completer.complete(eta);
          } else {
            log('error in getETA');
            completer.complete('Error: $status');
          }
        });
        return completer.future;
      } } );
    }

}