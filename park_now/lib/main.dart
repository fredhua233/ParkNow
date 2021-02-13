import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Utils.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GoogleMapController mapController;
  FirebaseFirestore db;
  Position currentPos;
  Set<Marker> _markers = new Set();
  TextEditingController _name = new TextEditingController();
  TextEditingController _phone = new TextEditingController();
  TextEditingController _message = new TextEditingController();
  TextEditingController _plate = new TextEditingController();

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

  void fetchData(BuildContext context) {
    _markers.clear();
    users.get().asStream().asBroadcastStream().forEach((snap) {
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
                            content: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    Expanded(
                                        child: Text(
                                            'Name: ' + doc.data()['Name'])),
                                    Expanded(
                                        child: Text(
                                            'Phone: ' + doc.data()['Phone'])),
                                    Expanded(
                                        child: Text(
                                            'Plate: ' + doc.data()['Plate'])),
                                    Expanded(
                                        child: Text('Message: ' +
                                            doc.data()['Message'])),
                                  ],
                                )));
                      }),
                ),
                icon: BitmapDescriptor.defaultMarker));
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Getting everybody that are using the app

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

                                  // Dialog to fill in details
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      // return object of type Dialog
                                      return AlertDialog(
                                        title: new Text("Contact Me!"),
                                        content: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    decoration: InputDecoration(
                                                      border:
                                                          OutlineInputBorder(),
                                                      labelText: 'Name',
                                                    ),
                                                    controller: _name,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: TextField(
                                                    decoration: InputDecoration(
                                                      border:
                                                          OutlineInputBorder(),
                                                      labelText: 'Phone Number',
                                                    ),
                                                    controller: _phone,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: TextField(
                                                      decoration:
                                                          InputDecoration(
                                                        border:
                                                            OutlineInputBorder(),
                                                        labelText: 'Message',
                                                      ),
                                                      controller: _message),
                                                ),
                                                Expanded(
                                                  child: TextField(
                                                      decoration:
                                                          InputDecoration(
                                                        border:
                                                            OutlineInputBorder(),
                                                        labelText: 'Plate',
                                                      ),
                                                      controller: _plate),
                                                ),
                                              ],
                                            )),
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
                                                  'Lat', current.latitude);
                                              await _pref.setDouble(
                                                  'Long', current.longitude);
                                              await users.add({
                                                'Loc': current.toString(),
                                                'lat': currentPos.latitude,
                                                'long': currentPos.longitude,
                                                'Name': name,
                                                'Phone': phone,
                                                'Message': message,
                                                "Plate": plate,
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
                                    _markers.removeWhere((element) =>
                                        element.markerId.value ==
                                        _pref.getString('Loc'));
                                  });

                                  users
                                      .where('Loc',
                                          isEqualTo: _pref.getString('Loc'))
                                      .get()
                                      .then((qSnap) {
                                    qSnap.docs.forEach((doc) {
                                      DocumentReference thisDoc =
                                          users.doc(doc.id);
                                      thisDoc.delete();
                                    });
                                  });
                                  await _pref.setString('Loc', 'None');
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
                                            zoom: 14)));
                              }))),
                ],
              );
            } else {
              return CircularProgressIndicator();
            }
          }),
    ));
  }
}
