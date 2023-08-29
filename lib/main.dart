import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';


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
  final StreamController<LatLng> _streamController =
      StreamController.broadcast();

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
            return FutureBuilder<LatLng>(
              future: _getCurrentLocation(),
              builder: (BuildContext context, AsyncSnapshot<LatLng> userSnapshot) {
                final userCoords = userSnapshot.data;
                return FlutterMap(
                  options: MapOptions(
                    center: issCoords,
                    zoom: 17,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: ['a', 'b', 'c'],
                    ),
                    MarkerLayer(markers: [
                      if (userCoords != null)
                        Marker(
                          point: userCoords,
                          builder: (ctx) => Icon(
                            Icons.person_pin_circle,
                            color: Colors.blue,
                          ),
                        ),
                      Marker(
                        point: issCoords,
                        builder: (ctx) => Icon(
                          Icons.location_on,
                          color: Colors.red,
                        ),
                      ),
                    ]),
                  ],
                );
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
    LocationPermission permission = await Geolocator.requestPermission();
  }

  Future<LatLng> _getCurrentLocation() async {
    if((Geolocator.checkPermission() == 'always') || (Geolocator.checkPermission() == 'whileInUse')){
        final Position position =
            await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        return LatLng(position.latitude, position.longitude);
      } else {
        Geolocator.requestPermission();
      }
      final Position position =
            await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        return LatLng(position.latitude, position.longitude);
    }


  @override
  void dispose() {
    _streamController.close();
    super.dispose();
  }
}
