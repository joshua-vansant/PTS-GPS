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

// START: Eagle Rock
// Lot 540
// Alpine
// Lodge
// Cent
// UHall
// Lot 103
// Cent 
// Lodge
// Alpine
// 540
// Eagle Rock
// (580 is not in service currently)
class MapService {
   geo.GeolocatorPlatform geolocatorPlatform = geo.GeolocatorPlatform.instance;
  List<Map<String, Point>> shuttleStops = [
  {'University Hall Stop': Point(coordinates: Position(-104.78774864932078, 38.889464319662274)),},  
  {'Lot 103 Stop': Point(coordinates: Position(-104.79204688588112, 38.888782337417965)),},
  {'Centennial Hall Stop': Point(coordinates: Position(-104.79925147404836, 38.89193096726863)),},
  {'Lodge Stop': Point(coordinates: Position(-104.80542674163705, 38.89436248896465)),},  
  {'Alpine Stop': Point(coordinates: Position(-104.80652117718797, 38.897690997528024)),},
  {'Lot 540 Stop': Point(coordinates: Position(-104.81070532677619, 38.89998202956692)),},
  {'Eagle Rock Stop': Point(coordinates: Position(-104.8146366565121, 38.90254986221832)),},
  // {'Old Lot 576 Stop': Point(coordinates: Position(-104.81423941171502, 38.90519322228293)),},
  {'Lot 580 Stop': Point(coordinates: Position(-104.81500644128867, 38.90714636447364)),},
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
  
  onMapCreated(MapboxMap mapboxMap, PointAnnotationManager pointAnnotationManager) {
    // this.mapboxMap = mapboxMap;
    mapboxMap!.gestures.updateSettings(GesturesSettings(
      // rotateEnabled: false, 
      // pinchPanEnabled: false, 
      // // pinchToZoomEnabled: false,
      // doubleTapToZoomInEnabled: false,
      // doubleTouchToZoomOutEnabled: false,
      // pitchEnabled: false,
      // quickZoomEnabled: false,
      // scrollEnabled: false,
       ));
    mapboxMap!.location.updateSettings(LocationComponentSettings(enabled: true)); // show current position
    mapboxMap!.compass.updateSettings(CompassSettings(enabled: false,));
    mapboxMap!.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
      // this.mapboxMap!.setBounds(
      //   CameraBoundsOptions(bounds: CoordinateBounds
      //   (southwest: Point(coordinates: Position(-104.8249904837867, 38.88429262072977)).toJson(),
      //   northeast:  Point(coordinates: Position(-104.77047495032352, 38.922085601235615)).toJson(), 
      //   infiniteBounds: false,)
      //   , minZoom: 10
      //   , maxZoom: 20
      //   ));
    
    mapboxMap.annotations.createPointAnnotationManager().then((value) async {
      pointAnnotationManager = value;
      addShuttleStopsToMap(pointAnnotationManager);
    });
  }

  Future<void> addShuttleStopsToMap(PointAnnotationManager pointAnnotationManager) async {
    if (pointAnnotationManager == null) {
      log('pointAnnotationManger is null');
      return;
    }

    Uint8List imageBytes = await getImageBytes('assets/bus_stop_red.png');
    final decodedImage = await decodeImageFromList(imageBytes);
    int imageHeight = decodedImage.height;
    int imageWidth = decodedImage.width;
    log('imageHeight=$imageHeight, imageWidth=$imageWidth');

    for (final stop in shuttleStops) {
      final name = stop.keys.first;
      final point = stop.values.first;
      pointAnnotationManager?.create(PointAnnotationOptions(
        textField: name,
        textOffset: [0, -1.5],
        geometry: point.toJson(),
        iconSize: .3,
        textSize: 14,
        symbolSortKey: 1,
        image: imageBytes,
        iconAnchor: IconAnchor.BOTTOM,
      ));
    }
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
    return position;
  }

  Future<void> getUserLocation() async {
    var permission = await geo.Geolocator.checkPermission();
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
    log('creating marker');
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
}