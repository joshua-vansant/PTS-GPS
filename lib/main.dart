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


// void main() async => runApp(MyApp());
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
  // String directionsKey = dotenv.env('DIRECTIONS_API_KEY', 'MAPBOX_MAPS_KEY').toString();

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
    final response = await http.get(
        Uri.parse(
            'https://api.init.st/data/v1/events/latest?accessKey=ist_rg6P7BFsuN8Ekew6hKsE5t9QoMEp2KZN&bucketKey=jmvs_pts_tracker'));

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final lng = double.parse(
          jsonResponse['tracker1']['value'].toString().split(',')[0]);
      final lat = double.parse(
          jsonResponse['tracker1']['value'].toString().split(',')[1]);
      final coords = Point(coordinates: Position(lat, lng));
      t1Coords = coords;
      _iotStream.add(coords);
      _createT1Marker();

      // Calculate ETA
      final origin = 'Denver';
      final destination = 'San Francisco';
      DirectionsService.init(dotenv.env['DIRECTIONS_API_KEY'] ?? 'Failed to load Directions API Key');
      // DirectionsService.init('AIzaSyCCyfB2dfaTATspTTMCMf5d1tedRYXAgZ0');
      final directionsService = DirectionsService();
      
      final request = DirectionsRequest(
        origin: origin,
        destination: destination,
        travelMode: TravelMode.driving,
      );

      directionsService.route(request,
          (DirectionsResult response, DirectionsStatus? status) {
        if (status == DirectionsStatus.ok) {
          final route = response.routes!.first;
          final duration = route.legs!.first.duration;
          print('ETA: ${duration!.value.toString()} minutes');
        } else {
          print('Error: $status');
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
      pointAnnotationManager?.create(
          PointAnnotationOptions(
              geometry: t1Coords!.toJson(),
              iconSize: .5,
              symbolSortKey: 10,
              image: list))
          .then((value) => tracker1 = value);
    } else {
      var point = Point.fromJson((tracker1!.geometry)!.cast());
      var newPoint = t1Coords!.toJson();
      tracker1?.geometry = newPoint;
      pointAnnotationManager?.update(tracker1!);
    }
    getUserLocation();
  }

  _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    this.mapboxMap!.location
        .updateSettings(LocationComponentSettings(enabled: true)); // show current position
    mapboxMap.annotations.createPointAnnotationManager().then((value) async {
      pointAnnotationManager = value;
    });
    setState(() {
      _createT1Marker();
    });
  }

  @override
  void initState() {
    super.initState();
    getUserLocation();
    Timer.periodic(Duration(seconds: 1), (timer) {
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
          title: Text('Map Screen'),
        ),
        body: StreamBuilder<Point>(
            stream: _iotStream.stream,
            initialData: t1Coords,
            builder: (BuildContext context, AsyncSnapshot<Point> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                log('waiting');
                return Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (snapshot.hasData) {
                t1Coords = snapshot.data;
                return MapWidget(
                  resourceOptions: ResourceOptions(
                    accessToken:
                        // '',
                        dotenv.env['MAPBOX_PUBLIC_ACCESS_TOKEN'] ?? 'Failed to load MapBox Access Token'
                  ),
                  key: ValueKey("mapWidget"),
                  cameraOptions: CameraOptions(
                      center: t1Coords!.toJson(), zoom: 11),
                  onMapCreated: _onMapCreated,
                );
              } else {
                log('else block - stream');
                return Center(child: Text('No data available'));
              }
            }));
  }
}
