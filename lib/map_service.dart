import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:google_directions_api/google_directions_api.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';


class MapService {
  APIService apiService = APIService();
   geo.GeolocatorPlatform geolocatorPlatform = geo.GeolocatorPlatform.instance;
  List<Map<String, Point>> shuttleStops = [
  {'Gateway Hall Stop': Point(coordinates: Position(-104.80296157732812, 38.89186724000255)),},  
  {'Centennial Stop': Point(coordinates: Position(-104.79906405070052, 38.891729971857785)),},
  {'University Hall Stop': Point(coordinates: Position(-104.78817384564272, 38.889471922347234)),},
  {'ROTC Stop': Point(coordinates: Position(-104.81458260704491, 38.90249651010308)),},  
  {'Lodge Stop': Point(coordinates: Position(-104.81464673627568, 38.91512778864399)),},
  ];

  Point? userCoords;



   String getNextKey(String currentKey, List<Map<String, Point>> shuttleStops) {
    int currentIndex = -1;
  
    // Find the index of the current key
    for (int i = 0; i < shuttleStops.length; i++) {
      if (shuttleStops[i].containsKey(currentKey)) {
        currentIndex = i;
        break;
      }
    }
    
    // Retrieve the next key
    if (currentIndex != -1) {
      int nextIndex = (currentIndex + 1) % shuttleStops.length;
      return shuttleStops[nextIndex].keys.first;
    }
    
    return ''; // Next key not found
  }

  void launchMaps(BuildContext context, String lat, String lng) async {
    String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    String appleMapsUrl = 'https://maps.apple.com/?q=$lat,$lng';
    String url = Theme.of(context).platform == TargetPlatform.iOS ? appleMapsUrl : googleMapsUrl;
    log('${await canLaunchUrl(Uri.parse(url))}');
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  void centerCameraOnLocation(MapboxMap? mapboxMap, Point location) {
    mapboxMap?.setCamera(CameraOptions(center: location.toJson(), zoom: 17 ));
  }

  void setBearingToTracker(MapboxMap? mapboxMap, double bearing){
    log('setting bearing!');
    mapboxMap?.getCameraState().then((value) {
      mapboxMap?.setCamera(CameraOptions( zoom: 17 ));
      mapboxMap?.flyTo(CameraOptions(bearing: bearing), MapAnimationOptions(duration: 2000));
    }
    );
  }
  
  // onMapCreated(MapboxMap mapboxMap, PointAnnotationManager pointAnnotationManager) {
  //   // this.mapboxMap = mapboxMap;
  //   mapboxMap!.gestures.updateSettings(GesturesSettings(
  //     rotateEnabled: false, 
  //     pinchPanEnabled: false, 
  //     // pinchToZoomEnabled: false,
  //     doubleTapToZoomInEnabled: false,
  //     doubleTouchToZoomOutEnabled: false,
  //     pitchEnabled: false,
  //     quickZoomEnabled: false,
  //     // scrollEnabled: false,
  //      ));
  //   mapboxMap!.location.updateSettings(LocationComponentSettings(enabled: true)); // show current position
  //   mapboxMap!.compass.updateSettings(CompassSettings(enabled: false,));
  //   mapboxMap!.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
  //     // this.mapboxMap!.setBounds(
  //     //   CameraBoundsOptions(bounds: CoordinateBounds
  //     //   (southwest: Point(coordinates: Position(-104.8249904837867, 38.88429262072977)).toJson(),
  //     //   northeast:  Point(coordinates: Position(-104.77047495032352, 38.922085601235615)).toJson(), 
  //     //   infiniteBounds: false,)
  //     //   , minZoom: 10
  //     //   , maxZoom: 20
  //     //   ));
    
  //   mapboxMap.annotations.createPointAnnotationManager().then((value) async {
  //     pointAnnotationManager = value;
  //     addShuttleStopsToMap(pointAnnotationManager);
  //   });
  // }

Future<void> addShuttleStopsToMap(PointAnnotationManager pointAnnotationManager) async {
  if (pointAnnotationManager == null) {
    log('pointAnnotationManger is null');
    return;
  }

  Uint8List imageBytes = await getImageBytes('assets/bus_stop_red.png');

  final pointAnnotations = shuttleStops.map((stop) {
    final name = stop.keys.first;
    final point = stop.values.first;
    return PointAnnotationOptions(
      textField: name,
      textOffset: [0, -1.5],
      geometry: point.toJson(),
      iconSize: .3,
      textSize: 14,
      symbolSortKey: 1,
      image: imageBytes,
      iconAnchor: IconAnchor.BOTTOM,
    );
  }).toList();

  pointAnnotationManager.createMulti(pointAnnotations);
}

  Future<Uint8List> getImageBytes(String imagePath) async {
    final ByteData bytes = await rootBundle.load(imagePath);
    
    return bytes.buffer.asUint8List();
  }

  String getClosestStop(Point point) {
    double minDistance = double.infinity;
    String closestStop = '';

    for (Map<String, Point> stop in shuttleStops) {
      Point stopCoords = stop.values.first;
      double distance = geolocatorPlatform.distanceBetween(
        point.coordinates.lat as double,
        point.coordinates.lng as double,
        stopCoords.coordinates.lat as double,
        stopCoords.coordinates.lng as double,
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestStop = stop.keys.first;
      }
    }
    return closestStop;
  }

  Point getValueByKey(String key) {
    Map<String, Point> map = shuttleStops.firstWhere((map) => map.containsKey(key), orElse: () => shuttleStops[4]);
    if (map != null) {
      Point value = Point(coordinates: Position(map[key]!.coordinates.lng, map[key]!.coordinates.lat));
      // log('getValueByKey returning: ${value.coordinates.toJson()}');
      return value;
    }
    return Point(coordinates: Position(0, 0)); // Key not found
  }

  geo.Position getUserCoords(geo.Position position){
    userCoords = Point(coordinates: Position(position.longitude, position.latitude));
    log('userCoords in func: ${userCoords!.coordinates.lat}, ${userCoords!.coordinates.lng}');
    return position;
  }

  Future<void> getUserLocation() async {
    var permission = await geo.Geolocator.checkPermission();
    log('permission: $permission');
    if(permission == geo.LocationPermission.whileInUse || permission == geo.LocationPermission.always){
      geo.Position position = await geo.Geolocator.getCurrentPosition(
      desiredAccuracy: geo.LocationAccuracy.high
      );
      getUserCoords(position);
    }

    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        getUserLocation();
      }
    }
    if (permission == geo.LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    } else {
      return Future.error('A problem occurred.');
    }
  }

    void createMarker(
    PointAnnotationManager? pointAnnotationManager,
    Point point,
    String imagePath,
    int trackerNumber,
    Function(PointAnnotation) updateTracker,
    PointAnnotation? tracker,
  ) async {
    final ByteData bytes = await rootBundle.load(imagePath);
    final Uint8List list = bytes.buffer.asUint8List();

    if (tracker == null) {
      pointAnnotationManager?.create(PointAnnotationOptions(
        textField: 'Shuttle $trackerNumber',
        textOffset: [0, 1.25],
        geometry: point.toJson(),
        iconSize: 1,
        symbolSortKey: 10,
        image: list,
      )).then((value) {
        updateTracker(value);
      });
    } else {
      Point.fromJson((tracker.geometry)!.cast());
      var newPoint = Point(
        coordinates: Position(point.coordinates.lng, point.coordinates.lat),
      ).toJson();

      if (trackerNumber == 1) {
        tracker.geometry = newPoint;
        pointAnnotationManager?.update(tracker);
        updateTracker(tracker);
      } else if (trackerNumber == 2) {
        tracker.geometry = newPoint;
        pointAnnotationManager?.update(tracker);
        updateTracker(tracker);
      }
    }
  }

  void getTrackers({
    required Map<String, dynamic> jsonResponse,
    required void Function(Point, Point) updateTrackerCoordinates,
    required void Function(Point) addToTracker1Stream,
    required void Function(Point) addToTracker2Stream,
  }) {
    final tracker1Value = jsonResponse['tracker1']['value'].toString();
    log(tracker1Value);
    final lat = double.parse(tracker1Value.split(',')[0]);
    final lng = double.parse(tracker1Value.split(',')[1]);
    final tracker1Point = Point(coordinates: Position(lng, lat));

    final tracker2Value = jsonResponse['tracker2']['value'].toString();
    final t2lat = double.parse(tracker2Value.split(',')[0]);
    final t2lng = double.parse(tracker2Value.split(',')[1]);
    final tracker2Point = Point(coordinates: Position(t2lng, t2lat));

    updateTrackerCoordinates(tracker1Point, tracker2Point);
    addToTracker1Stream(tracker1Point);
    addToTracker2Stream(tracker2Point);
  }
  
  
  bool isResponseEqual(dynamic response1, dynamic response2) {
    return response1['tracker1']['value'] == response2['tracker1']['value'] &&
          response1['tracker2']['value'] == response2['tracker2']['value'];
  }

  Future<Point> getClosestShuttle(Point stopLocation) async {
    double minDistance = double.infinity;
    Point closestShuttleLocation = Point(coordinates: Position(0, 0));
    dynamic jsonResponse = await apiService.fetchData();
    List<Point> shuttleLocations = [];
    final tracker1Value = jsonResponse['tracker1']['value'].toString();
    final t1Lat = double.parse(tracker1Value.split(',')[0]);
    final t1Lng = double.parse(tracker1Value.split(',')[1]);
    shuttleLocations.add(Point(coordinates: Position(t1Lng, t1Lat)));

    final tracker2Value = jsonResponse['tracker2']['value'].toString();
    final t2Lat = double.parse(tracker2Value.split(',')[0]);
    final t2Lng = double.parse(tracker2Value.split(',')[1]);
    shuttleLocations.add(Point(coordinates: Position(t2Lng, t2Lat)));

    for (Point shuttleLocation in shuttleLocations) {
      double distance = geo.GeolocatorPlatform.instance.distanceBetween(
        stopLocation.coordinates.lat as double,
        stopLocation.coordinates.lng as double,
        shuttleLocation.coordinates.lat as double,
        shuttleLocation.coordinates.lng as double,
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestShuttleLocation = shuttleLocation;
      }
    }
    log('closest shuttle is: ${closestShuttleLocation.coordinates.toJson()}');
    return closestShuttleLocation;
  }

}