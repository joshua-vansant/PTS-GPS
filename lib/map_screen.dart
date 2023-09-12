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
// import 'package:flutter/foundation.dart' show TargetPlatform;



class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  StreamController<Point> _tracker1Stream = StreamController.broadcast();
  StreamController<Point> _tracker2Stream = StreamController.broadcast();
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  PointAnnotation? tracker1, tracker2, userLocation;
  Point? t1Coords, t2Coords, userCoords;
  String? t1Eta, t2Eta, focusETA;
  String t1Approaching = '', t2Approaching = '';
  bool t1ButtonEnabled = true, t2ButtonEnabled = true;
  Timer? t1ETATimer;
  final cacheManager = DefaultCacheManager();
  geo.GeolocatorPlatform geolocatorPlatform = geo.GeolocatorPlatform.instance;

  List<Map<String, Point>> shuttleStops = [
  {
    'Gateway Hall Stop': Point(coordinates: Position(-104.80296157732812, 38.89186724000255)),
  },  
  {
    'Centennial Stop': Point(coordinates: Position(-104.79906405070052, 38.891729971857785)),
  },
  {
    'University Hall Stop': Point(coordinates: Position(-104.78817384564272, 38.889471922347234)),
  },
  {
    'ROTC Stop': Point(coordinates: Position(-104.81458260704491, 38.90249651010308)),
  },  
  {
    'Lodge Stop': Point(coordinates: Position(-104.81464673627568, 38.91512778864399)),
  },
  
  // Add more stops as needed
  ];


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

  void updateCurrentStop(Point userLocation, List<Map<String,Point>> shuttleStops, int trakcerNum) async {
    const double maxDistanceFeet = 300.0;
    const double metersPerFoot = 0.3048;
    double maxDistanceMeters = maxDistanceFeet * metersPerFoot;

    for (Map<String, Point> stop in shuttleStops) {
      Point stopCoords = stop.values.first;
      double distance = geolocatorPlatform.distanceBetween(
        userLocation.coordinates.lat as double,
        userLocation.coordinates.lng as double,
        stopCoords.coordinates.lat as double,
        stopCoords.coordinates.lng as double,
      );
      if (distance <= maxDistanceMeters) {
        setState(() {
          switch(trakcerNum){
            case 1: t1Approaching = 'Next Stop => ${getNextKey(stop.keys.first, shuttleStops)}'; break;
            case 2: t2Approaching = 'Next Stop => ${getNextKey(stop.keys.first, shuttleStops)}'; break;
            default: t1Approaching = 'Error in updateCurrentStop'; t2Approaching = 'Error in updateCurrentStop';
          }
        });
      }
    }
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

  bool isResponseEqual(dynamic response1, dynamic response2) {
    return response1['tracker1']['value'] == response2['tracker1']['value'] &&
          response1['tracker2']['value'] == response2['tracker2']['value'];
  }


  void _showPopup(String eta, String destination) {
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
              String stop = getClosestStop(userCoords!);
              Point stopLoc = getValueByKey(stop);
              String lat = stopLoc.coordinates.lat.toString();
              String lng = stopLoc.coordinates.lng.toString();
              _launchMaps(lat, lng);
            },
            child: const Text('Get Directions'),
            ),
          ],
        );
      },
    );
  }

  void _launchMaps(String lat, String lng) async {
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


  @override
  void initState() {
    super.initState();
    getUserLocation();
    
    dynamic previousResponse;

    Timer.periodic(const Duration(seconds: 1), (timer) {
      fetchData().then((value) {
        // log('fetchdata returned: $value');
        if(previousResponse == null || !isResponseEqual(previousResponse, value)){
          log('!isResponseEqual(previousResponse, value)');
          previousResponse = value;
          getTrackers(value);
          createMarker(t1Coords!, 'assets/bus_1.png', 1);
          createMarker(t2Coords!, 'assets/bus_2.png', 2);
      }
      },
      );
    });
    
    // //fetch initial ETA values
    // fetchData().then((value) {
    //   getTrackers(value);
    //   getETA(t1Coords!, t2Coords!, TravelMode.driving).then((value) => t1Eta = value);
    //   getETA(t2Coords!, t1Coords!, TravelMode.driving).then((value) => t2Eta = value);
    // });

    // //update displayed values every second
    // Timer.periodic(const Duration(seconds: 1), (timer) {
    //   fetchData().then(((value) { getTrackers(value); } ));
    //   setState(() {
    //     t1Eta = math.max(0, int.parse(t1Eta!) - 1).toString();  
    //     t2Eta = math.max(0, int.parse(t2Eta!) -1).toString();
    //     updateCurrentStop(t1Coords!, shuttleStops, 1);
    //     updateCurrentStop(t2Coords!, shuttleStops, 2);
    //   });

    //   //fetch new ETA values every 30 seconds
    //   if(timer.tick %30 == 0) {
    //     fetchData().then((_) => {
    //       getETA(t1Coords!, t2Coords!, TravelMode.driving).then((value) => t1Eta = value),
    //       getETA(t2Coords!, t1Coords!, TravelMode.driving).then((value) => t2Eta = value)
    //     });
    //   }
    // });
  }


  void _centerCameraOnLocation(Point location) {
    mapboxMap?.setCamera(CameraOptions( center: location.toJson() ));
  }

  geo.Position getUserCoords(geo.Position position){
    userCoords = Point(coordinates: Position(position.longitude, position.latitude));
    return position;
  }

  Future<void> getUserLocation() async {
    var permission = await geo.Geolocator.checkPermission();
    // log('permission for user location: ${permission.name}');
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


  void getTrackers(Map<String, dynamic> jsonResponse) {
    final tracker1Value = jsonResponse['tracker1']['value'].toString();
    final lat = double.parse(tracker1Value.split(',')[0]);
    final lng = double.parse(tracker1Value.split(',')[1]);
    final tracker1Point = Point(coordinates: Position(lng, lat));

    final tracker2Value = jsonResponse['tracker2']['value'].toString();
    final t2lat = double.parse(tracker2Value.split(',')[0]);
    final t2lng = double.parse(tracker2Value.split(',')[1]);
    final tracker2Point = Point(coordinates: Position(t2lng, t2lat));
    setState(() {
      t1Coords = tracker1Point;
      t2Coords = tracker2Point;
      _tracker1Stream.add(tracker1Point);
      _tracker2Stream.add(tracker2Point);
    });
  }


  Future<dynamic> fetchData() async {
    final response = await http.get(Uri.parse(
        'https://api.init.st/data/v1/events/latest?accessKey=ist_rg6P7BFsuN8Ekew6hKsE5t9QoMEp2KZN&bucketKey=jmvs_pts_tracker'));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      return jsonResponse;
    } else {
      throw Exception('Failed to load data');
    }
  }

  Future<String> getETA(Point origin, Point destination, TravelMode travelMode, [List<Point>? waypoints]) async {
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

  Future<void> createMarker(Point point, String imagePath, int trackerNumber) async {
    final ByteData bytes = await rootBundle.load(imagePath);
    final Uint8List list = bytes.buffer.asUint8List();
    PointAnnotation? tracker;
    // log('creating marker for ${point.coordinates.toJson()}');
    if (trackerNumber == 1) {
      tracker = tracker1;
    } else if (trackerNumber == 2) {
      tracker = tracker2;
    }

    if (tracker == null) {
      pointAnnotationManager?.create(PointAnnotationOptions(
        textField: 'Shuttle $trackerNumber',
        textOffset: [0, 1.25],
        geometry: point.toJson(),
        iconSize: 1,
        symbolSortKey: 10,
        image: list,
      )).then((value) {
        if (trackerNumber == 1) {
          setState(() {
            tracker1 = value;
            // log('tracker1 set to ${tracker1!.geometry}');
          });
        } else if (trackerNumber == 2) {
          setState(() {
            tracker2 = value;
            // log('tracker2 set to ${tracker2!.geometry}');
          });
          }
      });
    } else {
        Point.fromJson((tracker.geometry)!.cast());
        var newPoint = Point(coordinates: Position(point.coordinates.lng, point.coordinates.lat)).toJson();
        
        if(trackerNumber == 1){
          setState(() {
            tracker1!.geometry = newPoint;
            pointAnnotationManager?.update(tracker1!);
          });
        } else if (trackerNumber == 2){
          tracker2!.geometry = newPoint;
          pointAnnotationManager?.update(tracker2!);
        }
    }
  }

  Future<Uint8List> getImageBytes(String imagePath) async {
    final ByteData bytes = await rootBundle.load(imagePath);
    return bytes.buffer.asUint8List();
  }
  
  void addShuttleStopsToMap() async {
    if (pointAnnotationManager == null) {
      log('pointAnnotationManger is null');
      return;
    }

    for (final stop in shuttleStops) {
      final name = stop.keys.first;
      final point = stop.values.first;
      final imageBytes = await getImageBytes('assets/bus_stop_red.png');
      // log('creating a shuttle stop marker');
      pointAnnotationManager?.create(PointAnnotationOptions(
        textField: name,
        textOffset: [0, -1.5],
        // iconOffset: [0, -5],
        geometry: point.toJson(),
        iconSize: .3,
        symbolSortKey: 10,
        image: imageBytes,
      ));
    }
  }

  Future<Point> getClosestShuttle(Point stopLocation) async {
  double minDistance = double.infinity;
  Point closestShuttleLocation = Point(coordinates: Position(0, 0));

  dynamic jsonResponse = await fetchData();

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



  _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    this.mapboxMap!.gestures.updateSettings(GesturesSettings(rotateEnabled: false,  ));
    this.mapboxMap!.location.updateSettings(LocationComponentSettings(enabled: true)); // show current position
      // this.mapboxMap!.setBounds(
      //   CameraBoundsOptions(bounds: CoordinateBounds
      //   (southwest: Point(coordinates: Position(-104.82192257233655, 38.885950899335185)).toJson(), 
      //   northeast:  Point(coordinates: Position(-104.77512700039927, 38.913727655885715 )).toJson(), 
      //   infiniteBounds: false,)
      //   , minZoom: 10
      //   , maxZoom: 20
      //   ));
    mapboxMap.annotations.createPointAnnotationManager().then((value) async {
      pointAnnotationManager = value;
      addShuttleStopsToMap();
    });
  }

  void _showDialog(String stopString, Point closestShuttle) {
    Point stopPoint = getValueByKey(stopString);
    String eta; 
    getETA(closestShuttle, stopPoint, TravelMode.driving).then((value) {
      showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('ETA To $stopString'),
        content: Text('A shuttle should arrive at $stopString in around $value seconds'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Close'),
          ),
        ],
      );
    },
  );
    },);
  
}


  @override
  void dispose() {
    _tracker1Stream.close();
    _tracker2Stream.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    final double itemHeight = (size.height - kToolbarHeight - 24);
    final double itemWidth = size.width/2;
    return Column(
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
        Expanded(
          child: 
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                ElevatedButton(
                  onPressed: () {
                    Point GHStop = getValueByKey('Gateway Hall Stop');
                    _centerCameraOnLocation(GHStop);
                    getClosestShuttle(GHStop).then((value) {
                      _showDialog('Gateway Hall Stop', value);
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
                    Point centStop = getValueByKey('Centennial Stop');
                    _centerCameraOnLocation(centStop);
                    getClosestShuttle(centStop).then((value) {
                    _showDialog('Centennial Stop', value);
                  },
                  );
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
                    Point uHallStop = getValueByKey('University Hall Stop');
                    _centerCameraOnLocation(uHallStop);
                    getClosestShuttle(uHallStop).then((value) {
                      _showDialog('University Hall Stop', value);
                  },
                  );
                  },
                  style: const ButtonStyle(
                    backgroundColor: MaterialStatePropertyAll<Color>(Colors.orange),
                    foregroundColor: MaterialStatePropertyAll<Color>(Colors.black),),
                  child: const Text(textAlign: TextAlign.center, 'University Hall Stop'),
                ),
                ElevatedButton(
                  onPressed: () {
                    log('button pressed');
                    Point rotcStop = getValueByKey('ROTC Stop');
                    _centerCameraOnLocation(rotcStop);
                    getClosestShuttle(rotcStop).then((value) {
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
                    Point lodgeStop = getValueByKey('Lodge Stop');
                    _centerCameraOnLocation(lodgeStop);
                    getClosestShuttle(lodgeStop).then((value) {
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
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              getUserLocation();
              String closestStop = getClosestStop(userCoords!);
              Point closestStopPoint = getValueByKey(closestStop);
              String eta;
              getETA(userCoords!, closestStopPoint, TravelMode.driving).then((value) {
                eta = value;
                _showPopup(eta, closestStop);
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
    );
  }
}