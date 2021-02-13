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
  TextEditingController _info = new TextEditingController();
  CollectionReference users;
  bool parked = !(StorageUtil.getString('Loc') == 'None');
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

  @override
  Widget build(BuildContext context) {
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
                      initialCameraPosition: CameraPosition(
                        target:
                            LatLng(currentPos.latitude, currentPos.longitude),
                        zoom: 15.0,
                      ),
                      markers: _markers),

                  // Button to take up location
                  FloatingActionButton(
                    onPressed: () async {
                      if (!parked) {
                        LatLng current = new LatLng(
                            currentPos.latitude, currentPos.longitude);

                        // Dialog to fill in details
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            // return object of type Dialog
                            return AlertDialog(
                              title: new Text("Enter Details"),
                              content: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: TextField(
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(),
                                      labelText: 'Type in Your Info',
                                    ),
                                    controller: _info,
                                  )),
                              actions: <Widget>[
                                // usually buttons at the bottom of the dialog
                                FlatButton(
                                  // Saves revelant data to the cloud and shared pref
                                  child: new Text("Save"),
                                  onPressed: () async {
                                    String details = _info.text;
                                    await _pref.setString(
                                        'Loc', current.toString());

                                    await users.add({
                                      'Loc': current.toString(),
                                      'Details': details
                                    });
                                    // Create Marker
                                    setState(() {
                                      parked = true;
                                      _markers.add(Marker(
                                        // This marker id can be anything that uniquely identifies each marker.
                                        markerId: MarkerId(current.toString()),
                                        position: current,
                                        infoWindow: InfoWindow(
                                            title: 'My Location',
                                            snippet: details),
                                        icon: BitmapDescriptor
                                            .defaultMarkerWithHue(
                                                BitmapDescriptor.hueBlue),
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
                              element.markerId.value == _pref.getString('Loc'));
                        });

                        users
                            .where('Loc', isEqualTo: _pref.getString('Loc'))
                            .get()
                            .then((qSnap) {
                          qSnap.docs.forEach((doc) {
                            DocumentReference thisDoc = users.doc(doc.id);
                            thisDoc.delete();
                          });
                        });
                        await _pref.setString('Loc', 'None');
                      }
                    },
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    backgroundColor: Colors.green,
                    child: const Icon(Icons.add_location, size: 36.0),
                  ),
                ],
              );
            } else {
              return CircularProgressIndicator();
            }
          }),
    ));
  }
}
