import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:google_directions_api/google_directions_api.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: '.env');
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mapbox Maps Flutter Demo',
      home: MapScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

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
  bool t1ButtonEnabled = true, t2ButtonEnabled = true;


  @override
  void initState() {
    super.initState();
    getUserLocation();
    Timer.periodic(const Duration(seconds: 1), (timer) {
      fetchData().then((_){
        setState(() {
          getETA(t1Coords!, t2Coords!).then((value) => t1Eta = value);
          getETA(t2Coords!, t1Coords!).then((value) => t2Eta = value);
        });
      });
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
                  const TextSpan(
                      text: 'XshuttleStop\t|\t',
                      style: TextStyle(
                          fontSize: 19.0,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                    TextSpan(
                            text: t1Eta,
                            style: const TextStyle(
                              fontSize: 19.0,
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
                  const TextSpan(
                      text: 'XshuttleStop\t|\t',
                      style: TextStyle(
                          fontSize: 19.0,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  TextSpan(
                      text: t2Eta,
                      style: const TextStyle(
                          fontSize: 19.0,
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


  Point getTracker(Map<String, dynamic> jsonResponse, int trackerNumber) {
  final trackerKey = 'tracker$trackerNumber';
  final trackerValue = jsonResponse[trackerKey]['value'].toString();
  final lng = double.parse(trackerValue.split(',')[0]);
  final lat = double.parse(trackerValue.split(',')[1]);
  final trackerCoords = Point(coordinates: Position(lat, lng));

  if (trackerNumber == 1) {
    t1Coords = trackerCoords;
    _tracker1Stream.add(trackerCoords);
  } else if (trackerNumber == 2) {
    t2Coords = trackerCoords;
    _tracker2Stream.add(trackerCoords);
  }

  return trackerCoords;
}


  Future<void> fetchData() async {
    final response = await http.get(Uri.parse(
        'https://api.init.st/data/v1/events/latest?accessKey=ist_rg6P7BFsuN8Ekew6hKsE5t9QoMEp2KZN&bucketKey=jmvs_pts_tracker'));

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      getTracker(jsonResponse, 1);
      createMarker(t1Coords!, 'assets/shuttle_marker.png', 1);
      getTracker(jsonResponse, 2);
      createMarker(t2Coords!, 'assets/shuttle_marker.png', 2);
      getUserLocation();
    } else {
      throw Exception('Failed to load data');
    }
  }

 Future<String> getETA(Point origin, Point destination, [List<Point>? waypoints]) async {
  final originStr = '${origin.coordinates.lat}, ${origin.coordinates.lng}';
  final destinationStr = '${destination.coordinates.lat}, ${destination.coordinates.lng}';
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

  directionsService.route(request, (DirectionsResult response, DirectionsStatus? status) {
    if (status == DirectionsStatus.ok) {
      final route = response.routes!.first;
      final duration = route.legs!.first.duration;
      completer.complete('${duration!.value.toString()}');
    } else {
      completer.complete('Error: $status');
    }
  });
  return completer.future;
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
          tracker1 = value;
        } else if (trackerNumber == 2) {
          tracker2 = value;
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
