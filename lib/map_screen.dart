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

  String xShuttleStop = ''; // Initialize the xShuttleStop variable
  // List<String> shuttleStops = [
  //   'Gateway Hall Stop',
  //   'Centennial Stop',
  //   'University Hall Stop',
  //   'ROTC Stop',
  //   'Lodge Stop'
  // ]; // Define the shuttle stops in order

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
  // log('updating current stop from ${userLocation.toJson()} for tracker$trakcerNum');
  const double maxDistanceFeet = 300.0;
  const double metersPerFoot = 0.3048;
  double maxDistanceMeters = maxDistanceFeet * metersPerFoot;
  // const double maxDistance = 91.44; // 300 feet in meters

  for (Map<String, Point> stop in shuttleStops) {
    Point stopCoords = stop.values.first;
    double distance = geolocatorPlatform.distanceBetween(
      userLocation.coordinates.lat as double,
      userLocation.coordinates.lng as double,
      stopCoords.coordinates.lat as double,
      stopCoords.coordinates.lng as double,
    );
    // log('distance from tracker$trakcerNum: ${userLocation.coordinates.toJson()} to ${stop.values.first.coordinates.toJson()} is: $distance meters.');
    if (distance <= maxDistanceMeters) {
      // log('found a distance less than maxDistance! UPDATING T1APPROACHING');
      setState(() {
        switch(trakcerNum){
          case 1: t1Approaching = 'Next Stop => ${getNextKey(stop.keys.first, shuttleStops)}';
          case 2: t2Approaching = 'Next Stop => ${getNextKey(stop.keys.first, shuttleStops)}';
          // case 1: t1Approaching = stop.keys.first; break;
          // case 2: t2Approaching = stop.keys.first; break;
          default: t1Approaching = 'Error in updateCurrentStop'; t2Approaching = 'Error in updateCurrentStop';
        }
      });
      break;
    }
  }
}


String getClosestStop(Point point, List<Map<String, Point>> shuttleStops) {
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

  Point getValueByKey(String key, List<Map<String, Point>> list) {
  Map<String, Point> map = list.firstWhere((map) => map.containsKey(key), orElse: () => shuttleStops[4]);
  if (map != null) {
    // log('map key: ${map[key]!.toString()}');
    Point value = Point(coordinates: Position(map[key]!.coordinates.lng, map[key]!.coordinates.lat));
    log('getValueByKey returning: ${value.coordinates.toJson()}');
    return value;
  }
  return Point(coordinates: Position(0, 0)); // Key not found
}

// void updateXShuttleStop(String currentStop, int trackerNum) async {
//   log('updateXStop: $currentStop, $trackerNum');
//   int currentIndex = shuttleStops.indexOf(currentStop);
//   if (currentIndex == -1) {
//     xShuttleStop = ''; // Reset the xShuttleStop if currentStop is not found
//   }

//   int nextIndex = currentIndex + 1;
//   if (nextIndex >= shuttleStops.length) {
//     nextIndex = 0;// Reset the xShuttleStop if currentStop is the last stop
//   }

//   String nextStop = shuttleStops[nextIndex];
//   xShuttleStop = nextStop;
//   switch(trackerNum){
//     case 1: setState(() {
//       t1Approaching = xShuttleStop;
//     }); break;
//     case 2: setState(() {
//       t2Approaching = xShuttleStop;
//     }); break;
//     default: setState(() {t1Approaching = 'Error in getStops()'; t2Approaching = 'Error in getStops()';});
//   }
// }

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
              // Handle button press
              Navigator.of(context).pop();
            },
            child: Text('Close'),
          ),
          TextButton(onPressed: () {
            String stop = getClosestStop(userCoords!, shuttleStops);
            Point stopLoc = getValueByKey(stop, shuttleStops);
            // _launchMaps(getClosestStop(userCoords!, shuttleStops));
            String lat = stopLoc.coordinates.lat.toString();
            String lng = stopLoc.coordinates.lng.toString();
            log('launching Maps');
            _launchMaps(lat, lng);
          },
          child: Text('Get Directions'),
          ),
        ],
      );
    },
  );
}

void _launchMaps(String lat, String lng) async {
  String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
  log('google URL= $googleMapsUrl');
  String appleMapsUrl = 'https://maps.apple.com/?q=$lat,$lng';
  log('apple url = $appleMapsUrl');
  String url = Theme.of(context).platform == TargetPlatform.iOS ? appleMapsUrl : googleMapsUrl;
  log('url= $url');
  log('${await canLaunchUrl(Uri.parse(url))}');
  if (await canLaunchUrl(Uri.parse(url))) {
    log('trying to launch URL');
    await launchUrl(Uri.parse(url));
  } else {
    throw 'Could not launch $url';
  }
}




  @override
  void initState() {
    super.initState();
    getUserLocation();

    //fetch initial ETA values
    fetchData().then((value) {
      getTrackers(value);
      getETA(t1Coords!, t2Coords!, TravelMode.driving).then((value) => t1Eta = value);
      getETA(t2Coords!, t1Coords!, TravelMode.driving).then((value) => t2Eta = value);
    });

    //update displayed values every second
    Timer.periodic(const Duration(seconds: 1), (timer) {
      fetchData().then(((value) {
        getTrackers(value);
      }));
      setState(() {
        t1Eta = math.max(0, int.parse(t1Eta!) - 1).toString();  
        t2Eta = math.max(0, int.parse(t2Eta!) -1).toString();
        updateCurrentStop(t1Coords!, shuttleStops, 1);
        updateCurrentStop(t2Coords!, shuttleStops, 2);
            });

       //fetch new ETA values every 30 seconds
       if(timer.tick %30 == 0) {
        fetchData().then((_) => {
          getETA(t1Coords!, t2Coords!, TravelMode.driving).then((value) => t1Eta = value),
          getETA(t2Coords!, t1Coords!, TravelMode.driving).then((value) => t2Eta = value)
        });
       }
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
    return ScaffoldMessenger(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('UCCS Shuttle Tracker'),
          backgroundColor: Colors.black, 
          centerTitle: true,
        ),
      backgroundColor: Colors.black,
      body: Stack(
        children:[Column(
        children: [
          Expanded(
            child: StreamBuilder<Point>(
                stream: _tracker1Stream.stream,
                initialData: t1Coords,
                builder: (BuildContext context, AsyncSnapshot<Point> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (snapshot.hasData) {
                    t1Coords = snapshot.data;
                    return MapWidget(
                      resourceOptions: ResourceOptions(
                          accessToken: dotenv.env['MAPBOX_PUBLIC_ACCESS_TOKEN'] ??
                              'Failed to load MapBox Access Token'),
                      key: const ValueKey("mapWidget"),
                      cameraOptions: CameraOptions(
                          center: t1Coords!.toJson(), zoom: 14, bearing: 300
                          ),
                      onMapCreated: _onMapCreated,
                      
                    );
                  } else {
                    return const Center(child: Text('No data available'));
                  }
                }),
          ), 
      //   Padding(
      //   padding: const EdgeInsets.all(16.0),
      //   child: RichText(
      //     text: TextSpan(
      //       text: focusETA ?? '',
      //     ),
      //   ),
      // ),
      ],
      )
      , Positioned(
      left: 0,
      right: 0,
      bottom: 16.0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ElevatedButton(
          onPressed: () {
            // Get user location, show nearest shuttle stop & when the next bus arrives
            // log('Getting closest stop: ${getClosestStop(userCoords!, shuttleStops)}');
            String closestStop = getClosestStop(userCoords!, shuttleStops);
            log('closestStop in onPressed $closestStop');
            // String destinationString = getValueByKey(closestStop, shuttleStops);
            Point destination = getValueByKey(closestStop, shuttleStops);//Point(coordinates: Position(destinationString.split(',')[1] as num, destinationString.split(',')[0] as num));
            log('destination in onPressed ${destination.coordinates.toString()}');
            String eta = 'test';
            _centerCameraOnLocation(userCoords!);
            getETA(userCoords!, destination, TravelMode.walking).then((value) { 
              eta = value;
               log('eta= $eta');
              _showPopup(eta, closestStop);
               });
          },
          child: Text('Find Nearest Shuttle'),
        ),
        )
        ),]
        ),
    drawer: 
      Drawer(backgroundColor: Colors.black,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(0.0, 35.0, 5.0, 0.0),
        children: [
          ListTile(
            title: RichText(
                text: TextSpan(
                    text: 'Shuttle 1:\n',
                    style: const TextStyle(
                        fontSize: 21.0,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        backgroundColor: Colors.black),
                    children: <TextSpan>[
                   TextSpan(
                      text: '$t1Approaching\t|\t',
                      style: TextStyle(
                          fontSize: 15.0,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                    TextSpan(
                            text: '$t1Eta seconds',
                            style: const TextStyle(
                              fontSize: 17.0,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ]
                )
                ),
                onTap: () => {
                  _centerCameraOnLocation(t1Coords!),
                  focusETA = 'Calculating ETA...',
                  setState(() {
                    focusETA = t1Eta;
                  }),
                  Navigator.pop(context)

                }
          ),
          ListTile(
            title: RichText(
                text: TextSpan(
                    text: 'Shuttle 2:\n',
                    style: const TextStyle(
                        fontSize: 21.0,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        backgroundColor: Colors.black),
                    children: <TextSpan>[
                   TextSpan(
                      text: '$t2Approaching\t|\t',
                      style: TextStyle(
                          fontSize: 15.0,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  TextSpan(
                      text: '$t2Eta seconds',
                      style: const TextStyle(
                          fontSize: 17.0,
                          color: Colors.green,
                          fontWeight: FontWeight.bold))
                ]
                )
                ),
                onTap: () => {
                  _centerCameraOnLocation(t2Coords!),
                  focusETA = 'Calculating ETA...',
                  setState(() {
                    focusETA = t2Eta;
                  }),
                  Navigator.pop(context)
                }
 )
        ],
      ),
      )
    ));
  }

  void _centerCameraOnLocation(Point location) {
  mapboxMap?.setCamera(CameraOptions(center: location.toJson())
  );
}


  Future<Position> getUserLocation() async {
    var permission = await geo.Geolocator.checkPermission();
    geo.Position position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high
    );
    userCoords = Point(coordinates: Position(position.longitude, position.latitude));
      
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
  // log('tracker1Point: ${tracker1Point.toJson()}');

  final tracker2Value = jsonResponse['tracker2']['value'].toString();
  final t2lat = double.parse(tracker2Value.split(',')[0]);
  final t2lng = double.parse(tracker2Value.split(',')[1]);
  final tracker2Point = Point(coordinates: Position(t2lng, t2lat));
  // log('tracker2Point: ${tracker2Point.toJson()}');
    setState(() {
      t1Coords = tracker1Point;
      t2Coords = tracker2Point;
      _tracker1Stream.add(tracker1Point);
      _tracker2Stream.add(tracker2Point);
      createMarker(t1Coords!, 'assets/bus_1.png', 1);
      createMarker(t2Coords!, 'assets/bus_2.png', 2);
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
  log('getETA origin: $originStr, destination: $destinationStr, travelMode: $travelMode');
  final cacheKey = '$originStr-$destinationStr';

  final fileStream = cacheManager.getFileFromCache(cacheKey);
  return fileStream.then((fileInfo) async {
    if (fileInfo != null && await fileInfo.file.exists()) {
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
    }
  });
}

  Future<void> createMarker(Point point, String imagePath, int trackerNumber) async {
    final ByteData bytes = await rootBundle.load(imagePath);
    final Uint8List list = bytes.buffer.asUint8List();
    // log('image loaded: $list');
    PointAnnotation? tracker;

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
            log('tracker1 set to ${tracker1!.geometry}');
          });
        } else if (trackerNumber == 2) {
          setState(() {
            tracker2 = value;
            log('tracker2 set to ${tracker2!.geometry}');
          });
        }
      });
    } else {
      // log('trying to update a marker');
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
      // tracker.geometry = newPoint;
      // log('tracker created at ${}')
      // pointAnnotationManager?.update(tracker);
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
  log('shuttle stops $shuttleStops');

  for (final stop in shuttleStops) {
    final name = stop.keys.first;
    final point = stop.values.first;
    final imageBytes = await getImageBytes('assets/bus_1.png');
    log('creating a shuttle stop marker');
    pointAnnotationManager?.create(PointAnnotationOptions(
      textField: name,
      textOffset: [0, -1.5],
      geometry: point.toJson(),
      iconSize: 1,
      symbolSortKey: 10,
      image: imageBytes,
    ));
  }
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
}