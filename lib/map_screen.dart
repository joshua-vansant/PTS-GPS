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
import 'map_service.dart';
// import 'package:flutter/foundation.dart' show TargetPlatform;



class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final APIService apiService = APIService();
  final MapService mapService = MapService();
  final StreamController<Point> _tracker1Stream = StreamController.broadcast();
  final StreamController<Point> _tracker2Stream = StreamController.broadcast();
  
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  PointAnnotation? tracker1, tracker2, userLocation;
  Point? t1Coords, t2Coords;
  String? t1Eta, t2Eta, focusETA;
  String t1Approaching = '', t2Approaching = '';
  bool t1ButtonEnabled = true, t2ButtonEnabled = true;
  Timer? t1ETATimer;
  geo.GeolocatorPlatform geolocatorPlatform = geo.GeolocatorPlatform.instance;

  @override
  void initState() {
    super.initState();
    mapService.getUserLocation();
    dynamic previousResponse;
    Timer.periodic(const Duration(seconds: 1), (timer) {
      apiService.fetchData().then((value) {
        // log('fetchdata returned: $value');
        if(previousResponse == null || mapService.isResponseEqual(previousResponse, value)){
          log('!isResponseEqual(previousResponse, value)');
          previousResponse = value;
          handleGetTrackers(value);
          _createMarker(t1Coords!, 'assets/bus_1.png', 1);
          _createMarker(t2Coords!, 'assets/bus_2.png', 2);
      }
      },
      );
    });
  }




  @override
  void dispose() {
    _tracker1Stream.close();
    _tracker2Stream.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey,
      child:
    Column(
      children: [ 
        Expanded(
          flex: 3,
          child: 
            MapWidget(
              resourceOptions: ResourceOptions(
                accessToken:
                  'pk.eyJ1IjoianZhbnNhbnRwdHMiLCJhIjoiY2w1YnI3ejNhMGFhdzNpbXA5MWExY3FqdiJ9.SNsWghIteFZD7DTuI4_FmA'),
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(-104.79610715806722, 38.89094045460431)).toJson(),
                zoom: 15,
                pitch: 70,
                bearing: 300),
              onMapCreated: _onMapCreated,
            ),
        ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 5,
                runSpacing: 5,
                children: [
                ElevatedButton(
                  onPressed: () {
                    Point gHallStop = mapService.getValueByKey('Gateway Hall Stop');
                    Point closestShuttle = Point(coordinates: Position(0, 0));
                    
                    mapService.getClosestShuttle(gHallStop).then((value) {
                     closestShuttle = value;
                     double bearing = bearingBetweenPoints(gHallStop, closestShuttle);
                     mapService.setBearingToTracker(mapboxMap, bearing);
                     mapService.centerCameraOnLocation(mapboxMap, gHallStop);
                    _showDialog('Gateway Hall Stop', closestShuttle);
                  },
                  );
                  },
                  style: const ButtonStyle(
                    backgroundColor: MaterialStatePropertyAll<Color>(Colors.amber),
                    foregroundColor: MaterialStatePropertyAll<Color>(Colors.black)),
                    child: const Text('Gateway Hall Stop', textAlign: TextAlign.center),
                ),
                ElevatedButton(
                  onPressed: () {
                    log('button pressed');
                    Point centStop = mapService.getValueByKey('Centennial Stop');
                    Point closestShuttle = Point(coordinates: Position(0, 0));
                    
                    mapService.getClosestShuttle(centStop).then((value) {
                      closestShuttle = value;
                      double bearing = bearingBetweenPoints(centStop, closestShuttle);
                      mapService.setBearingToTracker(mapboxMap, bearing);
                      mapService.centerCameraOnLocation(mapboxMap, centStop);
                      _showDialog('Centennial Stop', closestShuttle);
                    },);
                  },
                  style: const ButtonStyle(
                    backgroundColor: MaterialStatePropertyAll<Color>(Colors.green),
                    foregroundColor: MaterialStatePropertyAll<Color>(Colors.black),
                  ),
                  child: const Text(textAlign: TextAlign.center, 'Centennial Stop'),
                ),
                ElevatedButton(
                  onPressed: () {
                    log('button pressed');
                    Point closestShuttle = Point(coordinates: Position(0, 0));
                    Point uHallStop = mapService.getValueByKey('University Hall Stop');
                    
                    mapService.getClosestShuttle(uHallStop).then((value) {
                      closestShuttle = value;
                      double bearing = bearingBetweenPoints(uHallStop, closestShuttle);
                      mapService.setBearingToTracker(mapboxMap, bearing);
                      mapService.centerCameraOnLocation(mapboxMap, uHallStop);
                      _showDialog('University Hall Stop', value);
                    },);
                  },
                  style: const ButtonStyle(
                    backgroundColor: MaterialStatePropertyAll<Color>(Colors.orange),
                    foregroundColor: MaterialStatePropertyAll<Color>(Colors.black),),
                  child: const Text(textAlign: TextAlign.center, 'University Hall Stop'),
                ),
                ElevatedButton(
                  onPressed: () {
                    log('button pressed');
                    Point closestShuttle = Point(coordinates: Position(0, 0));
                    Point rotcStop = mapService.getValueByKey('ROTC Stop');
                    mapService.centerCameraOnLocation(mapboxMap, rotcStop);
                    mapService.getClosestShuttle(rotcStop).then((value) {
                      closestShuttle = value;
                      double bearing = bearingBetweenPoints(rotcStop, closestShuttle);
                      mapService.setBearingToTracker(mapboxMap, bearing);
                      _showDialog('ROTC Stop', value);
                  },
                  );
                  },
                  style: const ButtonStyle(
                    backgroundColor: MaterialStatePropertyAll<Color>(Colors.red),
                    foregroundColor: MaterialStatePropertyAll<Color>(Colors.black),),
                  child: const Text(textAlign: TextAlign.center, 'ROTC Stop'),
                ),
                ElevatedButton(
                  onPressed: () {
                    log('button pressed');
                    Point closestShuttle = Point(coordinates: Position(0, 0));
                    Point lodgeStop = mapService.getValueByKey('Lodge Stop');
                    mapService.centerCameraOnLocation(mapboxMap, lodgeStop);
                    mapService.getClosestShuttle(lodgeStop).then((value) {
                      closestShuttle = value;
                      double bearing = bearingBetweenPoints(lodgeStop, closestShuttle);
                      mapService.setBearingToTracker(mapboxMap, bearing);
                      _showDialog('Lodge Stop', value);
                  },
                  );
                  },
                  style: const ButtonStyle(
                    backgroundColor: MaterialStatePropertyAll<Color>(Colors.blue),
                    foregroundColor: MaterialStatePropertyAll<Color>(Colors.black),),
                  child: const Text(textAlign: TextAlign.center, 'Lodge Stop'),
                ),
              ],
            ),
          ),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              mapService.getUserLocation();
              String closestStop = mapService.getClosestStop(mapService.userCoords!);
              Point closestStopPoint = mapService.getValueByKey(closestStop);
              String eta;
              apiService.getETA(mapService.userCoords!, closestStopPoint, TravelMode.driving).then((value) {
                eta = value;
                showPopup(eta, closestStop);
              },
              );
            },
            style: const ButtonStyle(
              backgroundColor: MaterialStatePropertyAll<Color>(Colors.indigoAccent),
              foregroundColor: MaterialStatePropertyAll<Color>(Colors.black),),
            child: const Text('Find Closest Shuttle Stop'),
          ),
        ),
      ],
    ),
    );
  }

    void _updateTracker1(PointAnnotation value) {
    setState(() {
      tracker1 = value;
    });
  }


  void _updateTracker2(PointAnnotation value) {
    setState(() {
      tracker2 = value;
    });
  }

  void updateTrackerCoordinates(Point tracker1Point, Point tracker2Point) {
    setState(() {
      t1Coords = tracker1Point;
      t2Coords = tracker2Point;
    });
  }

  void addToTracker1Stream(Point point) {
    _tracker1Stream.add(point);
  }

  void addToTracker2Stream(Point point) {
    _tracker2Stream.add(point);
  }

  void handleGetTrackers(Map<String, dynamic> jsonResponse) {
    mapService.getTrackers(
      jsonResponse: jsonResponse,
      updateTrackerCoordinates: updateTrackerCoordinates,
      addToTracker1Stream: addToTracker1Stream,
      addToTracker2Stream: addToTracker2Stream,
    );
  }

  void updateT1Approaching(String message) {
    setState(() {
      t1Approaching = message;
    });
  }

  void updateT2Approaching(String message) {
    setState(() {
      t2Approaching = message;
    });
  }
  
  Future<void> _createMarker(Point point, String imagePath, int trackerNumber) async {
    if (trackerNumber == 1) {
      mapService.createMarker(
        pointAnnotationManager,
        point,
        imagePath,
        trackerNumber,
        _updateTracker1,
        tracker1,
      );
    } else if (trackerNumber == 2) {
      mapService.createMarker(
        pointAnnotationManager,
        point,
        imagePath,
        trackerNumber,
        _updateTracker2,
        tracker2,
      );
    }
  }


  void showPopup(String eta, String destination) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(destination),
          content: Text('$eta seconds'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
            TextButton(onPressed: () {
              String stop = mapService.getClosestStop(mapService.userCoords!);
              Point stopLoc = mapService.getValueByKey(stop);
              String lat = stopLoc.coordinates.lat.toString();
              String lng = stopLoc.coordinates.lng.toString();
              mapService.launchMaps(context, lat, lng);
            },
            child: const Text('Get Directions'),
            ),
          ],
        );
      },
    );
  }


  Future<Uint8List> getImageBytes(String imagePath) async {
    final ByteData bytes = await rootBundle.load(imagePath);
    
    return bytes.buffer.asUint8List();
  }
  



  double bearingBetweenPoints(Point point1, Point point2) {
    final lat1 = point1.coordinates.lat * (math.pi / 180);
    final lon1 = point1.coordinates.lng * (math.pi / 180);
    final lat2 = point2.coordinates.lat * (math.pi / 180);
    final lon2 = point2.coordinates.lng * (math.pi / 180);
    final y = math.sin(lon2 - lon1) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(lon2 - lon1);
    final bearing = math.atan2(y, x);
    final bearingDegrees = (bearing * 180 / math.pi + 360) % 360;
    return bearingDegrees;
  }

  _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    this.mapboxMap!.gestures.updateSettings(GesturesSettings(
      rotateEnabled: false, 
      pinchPanEnabled: false, 
      // pinchToZoomEnabled: false,
      doubleTapToZoomInEnabled: false,
      doubleTouchToZoomOutEnabled: false,
      pitchEnabled: false,
      quickZoomEnabled: false,
      // scrollEnabled: false,
       ));
    this.mapboxMap!.location.updateSettings(LocationComponentSettings(enabled: true)); // show current position
    this.mapboxMap!.compass.updateSettings(CompassSettings(enabled: false,));
    this.mapboxMap!.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
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
      mapService.addShuttleStopsToMap(value);
    });
  }

  void _showDialog(String stopString, Point closestShuttle) {
    Point stopPoint = mapService.getValueByKey(stopString);
    String eta; 
    apiService.getETA(closestShuttle, stopPoint, TravelMode.driving).then((value) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
          title: Center(child: Text('ETA To $stopString')),
          content: Text('A shuttle should arrive at $stopString in around $value seconds'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),],
            backgroundColor: Colors.blue[100],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            titleTextStyle: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              
            ),
            contentTextStyle: TextStyle(
              color: Colors.black87,
            ),
          );
        },
      );
    },);
  }
}