import 'dart:async';
import 'dart:convert';
// import 'dart:js_interop';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';


void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UCCS Shuttle Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final StreamController<LatLng> _streamController = StreamController.broadcast();
  MapboxMap? mapboxMap;
  PointAnnotation? pointAnnotation;
  PointAnnotationManager? pointAnnotationManager;
  int styleIndex = 1;
  var options = <PointAnnotationOptions>[];

  _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
  }


  // Point createRandomPoint() {
  //   return Point(coordinates: createRandomPosition());
  // }

  // Position createRandomPosition() {
  //   var random = Random();
  //   return Position(random.nextDouble() * -360.0 + 180.0,
  //       random.nextDouble() * -180.0 + 90.0);
  // }


  // void createOneAnnotation(Uint8List list) {
  //   pointAnnotationManager
  //       ?.create(PointAnnotationOptions(
  //           geometry: Point(
  //               coordinates: Position(
  //             0.381457,
  //             6.687337,
  //           )).toJson(),
  //           textField: "custom-icon",
  //           textOffset: [0.0, -2.0],
  //           textColor: Colors.red.value,
  //           iconSize: 1.3,
  //           iconOffset: [0.0, -5.0],
  //           symbolSortKey: 10,
  //           image: list
  //           )
  //           )
  //       .then((value) => pointAnnotation = value);
  // }



  // _createAnnotations(){
  //   mapboxMap!.annotations.createPointAnnotationManager().then((value) async {
  //     pointAnnotationManager = value;
  //     final ByteData bytes = await rootBundle.load('images/marker1.png');
  //     final Uint8List list = bytes.buffer.asUint8List();
  //     createOneAnnotation(list);
  //   });
  // }

  // void createOneAnnotation(Uint8List list) {
  //   pointAnnotationManager
  //     ?.create(
  //       PointAnnotationOptions(
  //         geometry: Point(coordinates: )
  //       )
  //     )
  // }

  Future<void> fetchData() async {
    final response =
        await http.get(Uri.parse('https://api.init.st/data/v1/events/latest?accessKey=ist_rg6P7BFsuN8Ekew6hKsE5t9QoMEp2KZN&bucketKey=jmvs_pts_tracker'));
        print(response.statusCode);
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final lat = double.parse(jsonResponse['tracker1']['value'].toString().split(',')[0]);
      final lng = double.parse(jsonResponse['tracker1']['value'].toString().split(',')[1]);
      final LatLng? coords = LatLng(lat, lng);
      _streamController.add(coords!);
    } else {
      throw Exception('Failed to load data');
    }
  }

  //   Future<Point> fetchDataPoint() async {
  //   final response =
  //       await http.get(Uri.parse('https://api.init.st/data/v1/events/latest?accessKey=ist_rg6P7BFsuN8Ekew6hKsE5t9QoMEp2KZN&bucketKey=jmvs_pts_tracker'));
  //       print(response.statusCode);
  //   if (response.statusCode == 200) {
  //     final jsonResponse = json.decode(response.body);
  //     final lat = double.parse(jsonResponse['tracker1']['value'].toString().split(',')[0]);
  //     final lng = double.parse(jsonResponse['tracker1']['value'].toString().split(',')[1]);
  //     final LatLng? coords = LatLng(lat, lng);
  //     _streamController.add(coords!);
  //     final Point point = Point(coordinates: Position(lng, lat));
  //     return point;
  //   } else {
  //     throw Exception('Failed to load data');
  //   }
  // }

  @override
  void initState() {
    super.initState();
    askPermission();
    Timer.periodic(Duration(seconds: 1), (timer) {
      fetchData().catchError((e) => print(e));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter StreamBuilder Example'),
      ),
      body: StreamBuilder<LatLng>(
        stream: _streamController.stream,
        builder: (BuildContext context, AsyncSnapshot<LatLng> snapshot) {
          if (snapshot.hasData) {
            final issCoords = snapshot.data!;
            print(issCoords);
            return FutureBuilder<LatLng>(
              future: _getCurrentLocation(),
              builder: (BuildContext context, AsyncSnapshot<LatLng> userSnapshot) {
                final userCoords = userSnapshot.data;
                print(userCoords);
              return MapWidget(
                key: ValueKey("mapWidget"),
                resourceOptions: ResourceOptions(
                  accessToken: 'pk.eyJ1IjoianZhbnNhbnRwdHMiLCJhIjoiY2w1YnI3ejNhMGFhdzNpbXA5MWExY3FqdiJ9.SNsWghIteFZD7DTuI4_FmA',
                  ),cameraOptions: CameraOptions(
                    center: issCoords.toJson(),
                    zoom: 13.5,
                  ),
                onMapCreated: _onMapCreated,
                onMapLoadedListener: (mapLoadedEventData) => {
                  mapboxMap?.annotations.createPointAnnotationManager().then((pointAnnotationManager) async {
                    final ByteData bytes = await rootBundle.load('assets/usericon.png');
                    final Uint8List list = bytes.buffer.asUint8List();
                    options = <PointAnnotationOptions>[];
                    options.add(PointAnnotationOptions(geometry: Point(coordinates: Position(userCoords!.latitude, userCoords.longitude)).toJson(),image: list, iconSize: 0.1));
                    // options.add(PointAnnotationOptions(geometry: Point(coordinates: Position(38, -104, 0)).toJson(), image: list,iconSize:0.1));
                    options.add(PointAnnotationOptions(geometry: issCoords.toJson(), image: list, iconSize: 0.2));
                    pointAnnotationManager.createMulti(options);
                  }
                  )
                },
                );

                // return FlutterMap(
                //   options: MapOptions(
                //     center: issCoords,
                //     zoom: 17,
                //   ),
                //   children: [
                //     TileLayer(
                //       urlTemplate:
                //           'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                //       subdomains: ['a', 'b', 'c'],
                //     ),
                //     MarkerLayer(markers: [
                //       if (userCoords != null)
                //         Marker(
                //           point: userCoords,
                //           builder: (ctx) => Icon(
                //             Icons.person_pin_circle,
                //             color: Colors.blue,
                //           ),
                //         ),
                //       Marker(
                //         point: issCoords,
                //         builder: (ctx) => Icon(
                //           Icons.location_on,
                //           color: Colors.red,
                //         ),
                //       ),
                //     ]),
                //   ],
                // );
              },
            );
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

 Future<void> askPermission() async{
    await geolocator.Geolocator.requestPermission();
  }

  Future<LatLng> _getCurrentLocation() async {
    // askPermission();
    if((geolocator.Geolocator.checkPermission() == 'always') || (geolocator.Geolocator.checkPermission() == 'whileInUse')){
        final geolocator.Position position =
            await geolocator.Geolocator.getCurrentPosition(desiredAccuracy: geolocator.LocationAccuracy.high);
        return LatLng(position.latitude, position.longitude);
      } else {
        askPermission();
      }
      final geolocator.Position position =
            await geolocator.Geolocator.getCurrentPosition(desiredAccuracy: geolocator.LocationAccuracy.high);
        return LatLng(position.latitude, position.longitude);
    }


  @override
  void dispose() {
    _streamController.close();
    super.dispose();
  }
}
