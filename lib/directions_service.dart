import 'package:google_directions_api/google_directions_api.dart';
import 'dart:developer';

void main() {
  DirectionsService.init('API_KEY');

  final directionsService = DirectionsService();

  const request = DirectionsRequest(
    origin: 'New York',
    destination: 'San Francisco',
    travelMode: TravelMode.driving,
    waypoints: [
      DirectionsWaypoint(location: 'Chicago, IL'),
      DirectionsWaypoint(location: 'Denver, CO'),
      DirectionsWaypoint(location: 'Las Vegas, NV'),
    ],
  );

  directionsService.route(request,
      (DirectionsResult response, DirectionsStatus? status) {
    if (status == DirectionsStatus.ok) {
      // do something with successful response
      final route = response.routes!.first;
      final duration = route.legs!.first.duration;
      log('ETA: ${duration!.toString()} minutes');
    } else {
      // do something with error response
    }
  });
}
