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
    );
  }
}

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  StreamController<Point> _iotStream = StreamController.broadcast();
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  PointAnnotation? tracker1;
  Point? t1Coords;
  PointAnnotation? userLocation;
  Point? userCoords;
  String? eta;

  @override
  void initState() {
    super.initState();
    getUserLocation();
    Timer.periodic(const Duration(seconds: 1), (timer) {
      fetchData();
    });
  }

  @override
  void dispose() {
    _iotStream.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                stream: _iotStream.stream,
                initialData: t1Coords,
                builder: (BuildContext context, AsyncSnapshot<Point> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    // log('waiting');
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
                          center: t1Coords!.toJson(), zoom: 14),
                      onMapCreated: _onMapCreated,
                    );
                  } else {
                    // log('else block - stream');
                    return const Center(child: Text('No data available'));
                  }
                }),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: RichText(
                text: TextSpan(

                    text: 'Shuttle 1\t|\t',
                    style: const TextStyle(
                        fontSize: 19.0,
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
                      text: eta,
                      style: const TextStyle(
                          fontSize: 19.0,
                          color: Colors.green,
                          fontWeight: FontWeight.bold))
                ])),
          ),
        ],
      ),
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

  Future<void> fetchData() async {
    final response = await http.get(Uri.parse(
        'https://api.init.st/data/v1/events/latest?accessKey=ist_rg6P7BFsuN8Ekew6hKsE5t9QoMEp2KZN&bucketKey=jmvs_pts_tracker'));

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final lng = double.parse(jsonResponse['tracker1']['value']
          .toString()
          .split(',')[0]);
      final lat = double.parse(jsonResponse['tracker1']['value']
          .toString()
          .split(',')[1]);
      final coords = Point(coordinates: Position(lat, lng));
      t1Coords = coords;
      _iotStream.add(coords);
      _createT1Marker();

      // Calculate ETA
      final origin = '${t1Coords!.coordinates.lat}, ${t1Coords!.coordinates.lng}';
      final destination = '38.89226825273266, -104.79764917960803';
      DirectionsService.init(
          dotenv.env['DIRECTIONS_API_KEY'] ?? 'Failed to load Directions API Key');
      final directionsService = DirectionsService();

      final request = DirectionsRequest(
        origin: origin,
        destination: destination,
        travelMode: TravelMode.driving,
        waypoints: [
          DirectionsWaypoint(location: '38.89122033268761, -104.79908324703885'),
          DirectionsWaypoint(location: '38.89154559249909, -104.79803199145594'),
          // DirectionsWaypoint(location: LatLng(38.892084300785534, -104.79797975515368)),
        ],
      );

      directionsService.route(request,
          (DirectionsResult response, DirectionsStatus? status) {
        if (status == DirectionsStatus.ok) {
          final route = response.routes!.first;
          final duration = route.legs!.first.duration;
          setState(() {
            eta = '${duration!.value.toString()} seconds';
          });
        } else {
          eta = 'Error: $status';
        }
      });
    } else {
      throw Exception('Failed to load data');
    }
  }

  Future<void> _createT1Marker() async {
    final ByteData bytes = await rootBundle.load('assets/userLocation.png');
    final Uint8List list = bytes.buffer.asUint8List();
    if (tracker1 == null) {
      pointAnnotationManager?.create(PointAnnotationOptions(
              textField: 'Shuttle 1',
              textOffset: [0, 1.25],
              geometry: t1Coords!.toJson(),
              iconSize: .3,
              symbolSortKey: 10,
              image: list))
          .then((value) => tracker1 = value);
    } else {
      Point.fromJson((tracker1!.geometry)!.cast());
      var newPoint = t1Coords!.toJson();
      tracker1?.geometry = newPoint;
      pointAnnotationManager?.update(tracker1!);
    }
    getUserLocation();
  }

  _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    this.mapboxMap!.gestures.updateSettings(GesturesSettings(rotateEnabled: false));
    this.mapboxMap!.location.updateSettings(LocationComponentSettings(enabled: true)); // show current position
    mapboxMap.annotations.createPointAnnotationManager().then((value) async {
      pointAnnotationManager = value;
    });
    setState(() {
      _createT1Marker();
    });
  }
}
