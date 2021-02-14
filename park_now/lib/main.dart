import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:geoflutterfire/geoflutterfire.dart';
import 'Utils.dart';
import 'dart:math';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GoogleMapController mapController;
  FirebaseFirestore db;
  // final geo = Geoflutterfire();
  static const BASE32_CODES = '0123456789bcdefghjkmnpqrstuvwxyz';

  Position currentPos;
  Set<Marker> _markers = new Set();
  TextEditingController _name = new TextEditingController();
  TextEditingController _phone = new TextEditingController();
  TextEditingController _message = new TextEditingController();
  TextEditingController _plate = new TextEditingController();

  double carDensity = 0;

  CollectionReference users;
  bool parked = !(StorageUtil.getString('Loc') == 'None' ||
      StorageUtil.getString('Loc') == '');
  SharedPreferences _pref;

  @override
  void initState() {
    super.initState();
    getPref();
    Firebase.initializeApp().whenComplete(() {
      setState(() {
        db = FirebaseFirestore.instance;
        users = db.collection('users');
      });
    });
  }

  getPref() async {
    _pref = await SharedPreferences.getInstance();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<Position> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permantly denied, we cannot request permissions.');
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return Future.error(
            'Location permissions are denied (actual value: $permission).');
      }
    }

    return await Geolocator.getCurrentPosition();
  }

  String encode(var latitude, var longitude, var numberOfChars) {
    var chars = [], bits = 0, bitsTotal = 0, hashValue = 0;
    double maxLat = 90, minLat = -90, maxLon = 180, minLon = -180, mid;

    while (chars.length < numberOfChars) {
      if (bitsTotal % 2 == 0) {
        mid = (maxLon + minLon) / 2;
        if (longitude > mid) {
          hashValue = (hashValue << 1) + 1;
          minLon = mid;
        } else {
          hashValue = (hashValue << 1) + 0;
          maxLon = mid;
        }
      } else {
        mid = (maxLat + minLat) / 2;
        if (latitude > mid) {
          hashValue = (hashValue << 1) + 1;
          minLat = mid;
        } else {
          hashValue = (hashValue << 1) + 0;
          maxLat = mid;
        }
      }

      bits++;
      bitsTotal++;
      if (bits == 5) {
        var code = BASE32_CODES[hashValue];
        chars.add(code);
        bits = 0;
        hashValue = 0;
      }
    }
    return chars.join('');
  }

  void fetchData(BuildContext context) {
    _markers.clear();
    users
        .where('geohash6',
            isEqualTo: encode(currentPos.latitude, currentPos.longitude, 6))
        .get()
        .asStream()
        .asBroadcastStream()
        .forEach((snap) {
      print(snap.docs);
      for (var doc in snap.docs) {
        if (doc.data()['Loc'] == _pref.getString('Loc')) {
          setState(() {
            _markers.add(Marker(
                // This marker id can be anything that uniquely identifies each marker.
                markerId: MarkerId(_pref.getString('Loc')),
                position:
                    LatLng(_pref.getDouble('Lat'), _pref.getDouble('Long')),
                infoWindow: InfoWindow(
                  title: 'My Spot',
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue)));
          });
        } else {
          // LatLng pt = new LatLng(doc.data()['lat'], doc.data()['long']);
          // if (bnds.contains(pt)) {
          setState(() {
            _markers.add(Marker(
                // This marker id can be anything that uniquely identifies each marker.
                markerId: MarkerId(doc.data()['Loc']),
                position: LatLng(doc.data()['lat'], doc.data()['long']),
                infoWindow: InfoWindow(
                  title: doc.data()['Plate'],
                  snippet: 'Click for Details...',
                  onTap: () => showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                            title: Text('Contact'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Expanded(
                                    child: Text('Name: ' + doc.data()['Name'])),
                                Expanded(
                                    child:
                                        Text('Phone: ' + doc.data()['Phone'])),
                                Expanded(
                                    child:
                                        Text('Plate: ' + doc.data()['Plate'])),
                                Expanded(
                                    child: Text(
                                        'Message: ' + doc.data()['Message'])),
                              ],
                            ));
                      }),
                ),
                icon: doc.data()['taken']
                    ? BitmapDescriptor.defaultMarker
                    : BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen)));
          });
          // }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Getting everybody that are using the app
    // fetchData(context);
    return MaterialApp(
        home: Scaffold(
      appBar: AppBar(
        title: Text('Map'),
        backgroundColor: Colors.blue,
      ),
      body: FutureBuilder<Position>(
          future: determinePosition(),
          builder: (BuildContext context, AsyncSnapshot<Position> snapshot) {
            if (snapshot.hasData) {
              currentPos = snapshot.data;
              return Stack(
                children: [
                  GoogleMap(
                      onMapCreated: _onMapCreated,
                      zoomControlsEnabled: false,
                      initialCameraPosition: CameraPosition(
                        target:
                            LatLng(currentPos.latitude, currentPos.longitude),
                        zoom: 15.0,
                      ),
                      markers: _markers),

                  // Button to take up location
                  Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                          padding: EdgeInsets.all(16),
                          child: FloatingActionButton.extended(
                              onPressed: () async {
                                if (!parked) {
                                  LatLng current = new LatLng(
                                      currentPos.latitude,
                                      currentPos.longitude);
                                  fetchData(context);

                                  // Dialog to fill in details
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      // return object of type Dialog
                                      return AlertDialog(
                                        title: new Text("Contact Me!"),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                decoration: InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  labelText: 'Name',
                                                ),
                                                controller: _name,
                                              ),
                                            ),
                                            Expanded(
                                              child: TextField(
                                                decoration: InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  labelText: 'Phone Number',
                                                ),
                                                controller: _phone,
                                              ),
                                            ),
                                            Expanded(
                                              child: TextField(
                                                  decoration: InputDecoration(
                                                    border:
                                                        OutlineInputBorder(),
                                                    labelText: 'Message',
                                                  ),
                                                  controller: _message),
                                            ),
                                            Expanded(
                                              child: TextField(
                                                  decoration: InputDecoration(
                                                    border:
                                                        OutlineInputBorder(),
                                                    labelText: 'Plate',
                                                  ),
                                                  controller: _plate),
                                            ),
                                          ],
                                        ),
                                        actions: <Widget>[
                                          // usually buttons at the bottom of the dialog
                                          FlatButton(
                                            // Saves revelant data to the cloud and shared pref
                                            child: new Text("Save"),
                                            onPressed: () async {
                                              String name = _name.text;
                                              String phone = _phone.text;
                                              String message = _message.text;
                                              String plate = _plate.text;
                                              await _pref.setString(
                                                  'Loc', current.toString());
                                              await _pref.setDouble(
                                                  'Lat', currentPos.latitude);
                                              await _pref.setDouble(
                                                  'Long', currentPos.longitude);
                                              await _pref.setString(
                                                  'geohash6',
                                                  encode(currentPos.latitude,
                                                      currentPos.longitude, 6));
                                              await _pref.setString(
                                                  'geohash10',
                                                  encode(currentPos.latitude,
                                                      currentPos.longitude, 9));

                                              // Implement replacement
                                              QuerySnapshot closeSpots =
                                                  await users
                                                      .where(
                                                          'geohash10',
                                                          isEqualTo: encode(
                                                              currentPos
                                                                  .latitude,
                                                              currentPos
                                                                  .longitude,
                                                              9))
                                                      .get();

                                              // since accurate up to 1 meter just take the first in the region
                                              if (closeSpots.size > 0) {
                                                DocumentReference closest =
                                                    closeSpots
                                                        .docs[0].reference;
                                                closest.delete();
                                              }

                                              await users.add({
                                                'Loc': current.toString(),
                                                'lat': currentPos.latitude,
                                                'long': currentPos.longitude,
                                                'Name': name,
                                                'Phone': phone,
                                                'Message': message,
                                                'Plate': plate,
                                                'geohash6': encode(
                                                    currentPos.latitude,
                                                    currentPos.longitude,
                                                    6),
                                                'geohash10': encode(
                                                    currentPos.latitude,
                                                    currentPos.longitude,
                                                    9),
                                                'taken': true
                                              });
                                              // Create Marker
                                              setState(() {
                                                parked = true;
                                                _markers.add(Marker(
                                                  // This marker id can be anything that uniquely identifies each marker.
                                                  markerId: MarkerId(
                                                      current.toString()),
                                                  position: current,
                                                  infoWindow: InfoWindow(
                                                      title: 'My Location',
                                                      snippet: name +
                                                          ", " +
                                                          phone +
                                                          "," +
                                                          plate +
                                                          "\n" +
                                                          message),
                                                  icon: BitmapDescriptor
                                                      .defaultMarkerWithHue(
                                                          BitmapDescriptor
                                                              .hueBlue),
                                                ));
                                              });

                                              Navigator.of(context).pop();
                                            },
                                          ),
                                          FlatButton(
                                            child: new Text("Cancel"),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                } else {
                                  setState(() {
                                    parked = false;
                                  });

                                  users
                                      .where('Loc',
                                          isEqualTo: _pref.getString('Loc'))
                                      .get()
                                      .then((qSnap) {
                                    qSnap.docs.forEach((doc) {
                                      doc.reference.update({'taken': false});
                                    });
                                  });
                                  await _pref.setString('Loc', 'None');
                                  await _pref.setDouble('Lat', 0);
                                  await _pref.setDouble('Long', 0);
                                  await _pref.setString('geohash6', 'None');
                                  await _pref.setString('geohash10', 'None');
                                  fetchData(context);
                                }
                              },
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              backgroundColor:
                                  parked ? Colors.red : Colors.green,
                              heroTag: 'release button',
                              label: parked
                                  ? Text('Release current spot')
                                  : Text('Take current spot'),
                              icon: parked
                                  ? const Icon(Icons.cancel, size: 36)
                                  : const Icon(Icons.add_location,
                                      size: 36.0)))),

                  Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                          padding: EdgeInsets.all(16),
                          child: FloatingActionButton(
                              child: const Icon(Icons.refresh),
                              onPressed: () => fetchData(context)))),

                  Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 50, 0, 0),
                          child: FloatingActionButton(
                              child: const Icon(Icons.navigation_rounded),
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blue,
                              onPressed: () {
                                mapController.animateCamera(
                                    CameraUpdate.newCameraPosition(
                                        CameraPosition(
                                            target: LatLng(currentPos.latitude,
                                                currentPos.longitude),
                                            zoom: 15)));
                              }))),

                  //Generate fake cars
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                        padding: EdgeInsets.all(16),
                        child: FloatingActionButton(
                            child: const Icon(Icons.navigation_rounded),
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue,
                            onPressed: () {
                              Random r = new Random();
                              for (var i = 0; i < 100; i++) {
                                double lat = currentPos.latitude +
                                    (0.005 - r.nextDouble() / 100);
                                double lon = currentPos.longitude +
                                    (0.005 - r.nextDouble() / 100);
                                users.add({
                                  'Loc': 'LatLng($lat, $lon)',
                                  'Message': 'N/A',
                                  'lat': lat,
                                  'long': lon,
                                  'Name': 'Bob$i',
                                  'Plate': 'ABC$i',
                                  'Phone': '$i',
                                  'geohash6': encode(lat, lon, 6),
                                  'geohash10': encode(lat, lon, 9),
                                  'taken': r.nextBool()
                                });
                              }
                            })),
                  )
                  //Generate fake cars
                  // Align(
                  //   alignment: Alignment.topCenter,
                  //   child: Padding(
                  //       padding: EdgeInsets.all(16),
                  //       child: FloatingActionButton(
                  //           child: const Icon(Icons.navigation_rounded),
                  //           backgroundColor: Colors.white,
                  //           foregroundColor: Colors.blue,
                  //           onPressed: () {
                  //             users.get().asStream().forEach((element) {
                  //               for (var doc in element.docs) {
                  //                 doc.reference.update({
                  //                   'geohash10': encode(doc.data()['lat'],
                  //                       doc.data()['long'], 9)
                  //                 });
                  //               }
                  //             });
                  //           })),
                  // )
                ],
              );
            } else {
              return CircularProgressIndicator();
            }
          }),
    ));
  }
}
