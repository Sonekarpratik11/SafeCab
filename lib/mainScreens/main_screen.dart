import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_place/google_place.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/phone_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  GoogleMapController? _mapController;

  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();

  final _polylinePoints = PolylinePoints();
  final Set<Marker> _markers = {};
  final List<LatLng> _polylineCoordinates = [];

  late final GooglePlace _googlePlace;

  LatLng _currentPosition = const LatLng(20.5937, 78.9629);
  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;

  String _selectedCab = 'Mini';
  String _fare = '₹120';
  String _selectedPaymentMethod = 'Cash';

  bool _isBooking = false;
  String _bookingStatus = 'Not Booked';

  @override
  void initState() {
    super.initState();
    _googlePlace = GooglePlace("AIzaSyDtLPhd47uHqR6o_BXB8sPzSPPFxhJQ734");
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    await Geolocator.requestPermission();
    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _pickupLatLng = _currentPosition;
      _addMarker(_currentPosition, 'pickup', 'Your Location');
      _moveCamera(_currentPosition);
    });
  }

  void _addMarker(LatLng position, String id, String title) {
    _markers.removeWhere((m) => m.markerId.value == id);
    _markers.add(
      Marker(
        markerId: MarkerId(id),
        position: position,
        infoWindow: InfoWindow(title: title),
      ),
    );
    setState(() {});
  }

  void _moveCamera(LatLng position) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
  }

  Future<void> _searchLocation(String query, bool isPickup) async {
    final result = await _googlePlace.search.getTextSearch(query);
    final location = result?.results?.first.geometry?.location;
    if (location != null) {
      final latLng = LatLng(location.lat!, location.lng!);
      setState(() {
        if (isPickup) {
          _pickupLatLng = latLng;
          _pickupController.text = result!.results!.first.name ?? '';
          _addMarker(latLng, 'pickup', 'Pickup');
        } else {
          _dropLatLng = latLng;
          _dropController.text = result!.results!.first.name ?? '';
          _addMarker(latLng, 'drop', 'Drop');
        }
      });
      _moveCamera(latLng);
      _drawPolyline();
    }
  }

  void _onMapTap(LatLng tappedPoint) {
    setState(() {
      _dropLatLng = tappedPoint;
      _dropController.text = 'Dropped Pin';
      _addMarker(tappedPoint, 'drop', 'Drop Location');
    });
    _drawPolyline();
  }

  Future<void> _drawPolyline() async {
    if (_pickupLatLng == null || _dropLatLng == null) return;

    final result = await _polylinePoints.getRouteBetweenCoordinates(
      "AIzaSyDtLPhd47uHqR6o_BXB8sPzSPPFxhJQ734",
      PointLatLng(_pickupLatLng!.latitude, _pickupLatLng!.longitude),
      PointLatLng(_dropLatLng!.latitude, _dropLatLng!.longitude),
    );

    if (result.points.isNotEmpty) {
      _polylineCoordinates.clear();
      for (var point in result.points) {
        _polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }
      setState(() {});
    }
  }
  void _bookRide() async {
    if (_pickupLatLng == null || _dropLatLng == null) return;

    setState(() {
      _isBooking = true;
      _bookingStatus = 'Booking...';
    });

    // Simulate API delay
    await Future.delayed(const Duration(seconds: 2));

    // Save booking details to Firestore
    await FirebaseFirestore.instance.collection('ride_requests').add({
      'pickup_lat': _pickupLatLng!.latitude,
      'pickup_lng': _pickupLatLng!.longitude,
      'drop_lat': _dropLatLng!.latitude,
      'drop_lng': _dropLatLng!.longitude,
      'cab_type': _selectedCab,
      'fare': _fare,
      'payment_method': _selectedPaymentMethod,
      'user_id': FirebaseAuth.instance.currentUser?.uid,
      'timestamp': Timestamp.now(),
      'status': 'Booked',
    });

    setState(() {
      _isBooking = false;
      _bookingStatus = 'Ride Booked!';
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ride Confirmed'),
        content: Text('Cab: $_selectedCab\nFare: $_fare\nPayment: $_selectedPaymentMethod'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }


  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PhoneScreen()),
    );
  }

  Widget _buildPaymentSelector() {
    return DropdownButton<String>(
      value: _selectedPaymentMethod,
      items: ['Cash', 'UPI', 'Card'].map((method) {
        return DropdownMenuItem(
          value: method,
          child: Text(method),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedPaymentMethod = value!;
        });
      },
    );
  }

  Widget _buildCabOptions() {
    final cabTypes = {
      'Mini': '₹120',
      'Sedan': '₹160',
      'SUV': '₹200',
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: cabTypes.entries.map((entry) {
        return ChoiceChip(
          label: Text('${entry.key}\n${entry.value}'),
          selected: _selectedCab == entry.key,
          onSelected: (_) {
            setState(() {
              _selectedCab = entry.key;
              _fare = entry.value;
            });
          },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user?.phoneNumber ?? 'User'),
              accountEmail: const Text('Welcome to Safe Cab'),
              currentAccountPicture: const CircleAvatar(child: Icon(Icons.person)),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to Profile screen
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to Settings screen
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help & Support'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to Help & Support screen
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('Safe Cab'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 14),
            onMapCreated: (controller) {
              _mapController = controller;
              _controller.complete(controller);
            },
            markers: _markers,
            polylines: {
              Polyline(
                polylineId: const PolylineId('route'),
                color: Colors.blue,
                width: 5,
                points: _polylineCoordinates,
              )
            },
            onTap: _onMapTap,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            top: 10,
            left: 15,
            right: 15,
            child: Column(
              children: [
                _locationTextField(_pickupController, 'Pickup Location', true),
                const SizedBox(height: 8),
                _locationTextField(_dropController, 'Drop Location', false),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            left: 15,
            right: 15,
            child: Card(
              elevation: 5,
              color: Colors.white.withOpacity(0.9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCabOptions(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Fare: $_fare', style: const TextStyle(fontSize: 16)),
                        _buildPaymentSelector(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _isBooking ? null : _bookRide,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                      child: Text(_isBooking ? 'Booking...' : 'Book Ride'),
                    ),
                    const SizedBox(height: 6),
                    Text('Status: $_bookingStatus'),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _locationTextField(TextEditingController controller, String hint, bool isPickup) {
    return TextField(
      controller: controller,
      onSubmitted: (value) => _searchLocation(value, isPickup),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.location_on),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
