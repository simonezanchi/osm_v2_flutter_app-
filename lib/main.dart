import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://wtxhengrdveaheaqeyzq.supabase.co',        // sostituisci con il tuo URL Supabase
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind0eGhlbmdyZHZlYWhlYXFleXpxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc0MTI2NTMsImV4cCI6MjA3Mjk4ODY1M30.OFBAi-_50p26dPeQQ6H_t3iltxDGts8k_vgmJKBFxK8',// sostituisci con la tua chiave anon
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenStreetMap Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Sticker Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _showMessage = false;
  Timer? _messageTimer;
  LatLng? _currentDeviceLocation;
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _locations = [];

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  void _displayTempMessage() {
    setState(() {
      _showMessage = true;
    });
    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showMessage = false;
        });
      }
    });
  }

  Future<void> _determineAndGoToCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Il servizio di localizzazione è disabilitato. Abilitalo per continuare.')));
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Permessi di localizzazione negati.')));
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Permessi di localizzazione negati permanentemente. Apri le impostazioni per abilitarli.')));
      }
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _currentDeviceLocation = LatLng(position.latitude, position.longitude);
      });

      if (_currentDeviceLocation != null) {
        _mapController.move(_currentDeviceLocation!, 15.0);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Posizione trovata: Lat: ${_currentDeviceLocation!.latitude}, Lng: ${_currentDeviceLocation!.longitude}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore nel recuperare la posizione: $e')));
      }
      print('Errore nel recuperare la posizione: $e');
    }
  }

  Future<void> _loadLocations() async {
    try {
      final data = await Supabase.instance.client
          .from('locations')
          .select();
      setState(() {
        _locations = List<Map<String, dynamic>>.from(data);
      });
      print('Dati caricati dal DB: $_locations');
    } catch (e) {
      print('Errore fetch locations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Trova la mia posizione',
            onPressed: _determineAndGoToCurrentPosition,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Aggiorna marker',
            onPressed: _loadLocations,
          ),
        ],
        toolbarHeight: 40.0,
      ),
      body: Stack(
        children: <Widget>[
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentDeviceLocation ??
                  const LatLng(45.6983, 9.6773), // default Bergamo
              initialZoom: _currentDeviceLocation != null ? 15.0 : 9.2,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'simone.zanchi.osm_v2',
              ),
              MarkerLayer(
                markers: _locations.map<Marker>((loc) {
                  return Marker(
                    point: LatLng(
                      double.parse(loc['lat'].toString()),
                      double.parse(loc['long'].toString()),
                    ),
                    width: 80,
                    height: 80,
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: EdgeInsets.all(10),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    loc['image_url'],
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  right: 8,
                                  child: Container(
                                    color: Colors.black54,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4, horizontal: 8),
                                    child: Text(
                                      loc['name'] ?? '',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: SizedBox(
                                    width: 120, // più grande
                                    height: 120, // più grande
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        loc['sticker_url'] ?? '',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: const Icon(Icons.location_on,
                          color: Colors.blue, size: 40),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          if (_showMessage)
            Center(
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Ciao',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _displayTempMessage,
        tooltip: 'Mostra Messaggio',
        child: const Icon(Icons.message),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
