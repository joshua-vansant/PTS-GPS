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

  String xShuttleStop = ''; // Initialize the xShuttleStop variable
  List<String> shuttleStops = [
    'Gateway Hall Stop',
    'Centennial Stop',
    'University Hall Stop',
    'ROTC Stop',
    'Lodge Stop'
  ]; // Define the shuttle stops in order

void updateXShuttleStop(String currentStop, int trackerNum) async {
  log('updateXStop: $currentStop, $trackerNum');
  int currentIndex = shuttleStops.indexOf(currentStop);
  if (currentIndex == -1) {
    xShuttleStop = ''; // Reset the xShuttleStop if currentStop is not found
  }

  int nextIndex = currentIndex + 1;
  if (nextIndex >= shuttleStops.length) {
    nextIndex = 0;// Reset the xShuttleStop if currentStop is the last stop
  }

  String nextStop = shuttleStops[nextIndex];
  xShuttleStop = nextStop;
  switch(trackerNum){
    case 1: setState(() {
      t1Approaching = xShuttleStop;
    }); break;
    case 2: setState(() {
      t2Approaching = xShuttleStop;
    }); break;
    default: setState(() {t1Approaching = 'Error in getStops()'; t2Approaching = 'Error in getStops()';});
  }
}


  @override
  void initState() {
    super.initState();
    getUserLocation();

    //fetch initial ETA values
    fetchData().then((value) {
      getTrackers(value);
      getETA(t1Coords!, t2Coords!).then((value) => t1Eta = value);
      getETA(t2Coords!, t1Coords!).then((value) => t2Eta = value);
      createMarker(t1Coords!, 'assets/shuttle_marker.png', 1);
      createMarker(t2Coords!, 'assets/shuttle_marker.png', 2);
    });


    //update displayed values every second
    Timer.periodic(const Duration(seconds: 1), (timer) {
      fetchData().then(((value) {
        getTrackers(value);
      }));
      setState(() {
        t1Eta = math.max(0, int.parse(t1Eta!) - 1).toString();  
        t2Eta = math.max(0, int.parse(t2Eta!) -1).toString();
            });

       //fetch new ETA values every 30 seconds
       if(timer.tick %30 == 0) {
        fetchData().then((_) => {
          getETA(t1Coords!, t2Coords!).then((value) => t1Eta = value),
          getETA(t2Coords!, t1Coords!).then((value) => t2Eta = value)
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
      body: Column(
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
                          center: t2Coords!.toJson(), zoom: 14),
                      onMapCreated: _onMapCreated,
                    );
                  } else {
                    return const Center(child: Text('No data available'));
                  }
                }),
          ), 
        Padding(
        padding: const EdgeInsets.all(16.0),
        child: RichText(
          text: TextSpan(
            text: focusETA ?? '',
          ),
        ),
      ),
      ],
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
  mapboxMap?.setCamera(CameraOptions(center: location.toJson(), zoom: 19)
  );
}


  Future<Position> getUserLocation() async {
    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        return Future.error('Location permissions are denied');
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
  final lng = double.parse(tracker1Value.split(',')[0]);
  final lat = double.parse(tracker1Value.split(',')[1]);
  final tracker1Point = Point(coordinates: Position(lat, lng));
  log('tracker1Point: ${tracker1Point.toJson()}');

  final tracker2Value = jsonResponse['tracker2']['value'].toString();
  final t2lng = double.parse(tracker2Value.split(',')[0]);
  final t2lat = double.parse(tracker2Value.split(',')[1]);
  final tracker2Point = Point(coordinates: Position(t2lat, t2lng));
  log('tracker2Point: ${tracker2Point.toJson()}');
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
      // getTracker(jsonResponse, 1);
      // createMarker(t1Coords!, 'assets/shuttle_marker.png', 1);
      // getTracker(jsonResponse, 2);
      // createMarker(t2Coords!, 'assets/shuttle_marker.png', 2);
      // getUserLocation();
      return jsonResponse;
    } else {
      throw Exception('Failed to load data');
    }
  }

Future<String> getETA(Point origin, Point destination, [List<Point>? waypoints]) async {
  final originStr = '${origin.coordinates.lat}, ${origin.coordinates.lng}';
  final destinationStr = '${destination.coordinates.lat}, ${destination.coordinates.lng}';

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
        travelMode: TravelMode.driving,
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
        iconSize: .3,
        symbolSortKey: 10,
        image: list,
      )).then((value) {
        if (trackerNumber == 1) {
          setState(() {
            tracker1 = value;
          });
        } else if (trackerNumber == 2) {
          setState(() {
            tracker2 = value;
          });
        }
      });
    } else {
      Point.fromJson((tracker.geometry)!.cast());
      var newPoint = point.toJson();
      tracker.geometry = newPoint;
      pointAnnotationManager?.update(tracker);
    }
  }
  

  _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    this.mapboxMap!.gestures.updateSettings(GesturesSettings(rotateEnabled: false));
    this.mapboxMap!.location.updateSettings(LocationComponentSettings(enabled: true)); // show current position
    mapboxMap.annotations.createPointAnnotationManager().then((value) async {
      pointAnnotationManager = value;
    });
  }
}