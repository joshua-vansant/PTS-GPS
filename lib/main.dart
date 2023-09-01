import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
// import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer';

void main() => runApp(MyApp());

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
  PointAnnotation? pointAnnotation;
  Point? t1Coords;

  Future<void> fetchData() async {
    final response = await http.get(
      Uri.parse('https://api.init.st/data/v1/events/latest?accessKey=ist_rg6P7BFsuN8Ekew6hKsE5t9QoMEp2KZN&bucketKey=jmvs_pts_tracker')
      );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final lng = double.parse(jsonResponse['tracker1']['value'].toString().split(',')[0]);
      final lat = double.parse(jsonResponse['tracker1']['value'].toString().split(',')[1]);
      final coords = Point(coordinates: Position(lat, lng));
      // setState(() {
      //   t1Coords = coords;
      //   log('coords set in fetchData $t1Coords');
      // });
      t1Coords = coords;
      log('coords set in fetchData ${t1Coords!.toJson()}');
      // log('adding coords to stream ${coords}');
      _iotStream.add(coords);
      _createMarker();
      
      
      // log('coords added to stream ${coords}');
      // return coords;
    } else {
      throw Exception('Failed to load data');
    }
  }

  // Future<void> _updateMarker() async {
  //   final ByteData bytes = await rootBundle.load('assets/userLocation.png');
  //   final Uint8List list = bytes.buffer.asUint8List();
  //   // pointAnnotationManager.update(annotation)
  //   pointAnnotationManager!.update(pointAnnotation: pointAnnotation);
  // }

  // }

  Future<void> _createMarker() async {
    final ByteData bytes = await rootBundle.load('assets/userLocation.png');
    final Uint8List list = bytes.buffer.asUint8List();
    // pointAnnotationManager.update(annotation)
    if (pointAnnotation == null) {
    pointAnnotationManager?.create(
      PointAnnotationOptions(
        geometry: t1Coords!.toJson(),
        iconSize: .5,
        symbolSortKey: 10,
        image: list)).then((value) => pointAnnotation = value);
  } else {
    log('trying to update to ${t1Coords!.toJson()}');
    // pointAnnotation = PointAnnotation(id: 't1', geometry: t1Coords!.toJson(), image: list, symbolSortKey: 10);
    // pointAnnotationManager?.update(pointAnnotation as PointAnnotation);
    

    if (pointAnnotation != null) {
          var point = Point.fromJson((pointAnnotation!.geometry)!.cast());
          var newPoint = t1Coords!.toJson();
          // Point(
          //     coordinates: Position(
          //         point.coordinates.lng + 1.0, point.coordinates.lat + 1.0));
          pointAnnotation?.geometry = newPoint;
          pointAnnotationManager?.update(pointAnnotation!);
        }
      
    
  }
  }

  _onMapCreated(MapboxMap mapboxMap){
    this.mapboxMap = mapboxMap;
    mapboxMap.annotations.createPointAnnotationManager().then((value) async {
      pointAnnotationManager = value;
      // _createMarker();
    });
    setState(() {
      _createMarker();
    });
  }

  @override
  void initState() {
    super.initState();
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
              if(snapshot.connectionState == ConnectionState.waiting){
                log('waiting');
                return Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (snapshot.hasData) {
                t1Coords = snapshot.data;
                // log('updated coords! ${t1Coords!.toJson().toString()}');
                return MapWidget(
                  resourceOptions: ResourceOptions(
                      accessToken: 'pk.eyJ1IjoianZhbnNhbnRwdHMiLCJhIjoiY2w1YnI3ejNhMGFhdzNpbXA5MWExY3FqdiJ9.SNsWghIteFZD7DTuI4_FmA',
                      ),
                  key: ValueKey("mapWidget"),
                  cameraOptions: CameraOptions(
                    center: t1Coords!.toJson(),
                    zoom: 5
                  ),
                  onMapCreated: _onMapCreated,
                  
                );
                
                } else {
                    log('else block - stream');
                    return Center(child: Text('No data available'));
             }
             })
        );
  }
}


