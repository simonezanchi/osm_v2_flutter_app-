import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'; // For LatLng
import 'dart:async';
import 'package:geolocator/geolocator.dart'; // For Geolocator

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenStreetMap Demo', // Changed title
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), // Changed seed color for variety
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Sticker Demo'), // Changed title
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
  LatLng? _currentDeviceLocation; // Per memorizzare la posizione del dispositivo
  final MapController _mapController = MapController(); // Controller per la mappa

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

  // --- NUOVO METODO PER LA POSIZIONE ---
  Future<void> _determineAndGoToCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Controlla se il servizio di localizzazione è abilitato sul dispositivo.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Il servizio di localizzazione non è abilitato.
      // Mostra un messaggio all'utente o chiedi di abilitarlo.
      if (mounted) { // mounted check
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Il servizio di localizzazione è disabilitato. Abilitalo per continuare.')));
      }
      return; // Non possiamo continuare
    }

    // 2. Controlla i permessi attuali.
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // I permessi sono negati, richiedili.
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // L'utente ha negato i permessi. Gestisci la situazione.
        if (mounted) { // mounted check
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permessi di localizzazione negati.')));
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // I permessi sono negati permanentemente. L'utente deve abilitarli
      // manualmente dalle impostazioni dell'app.
      if (mounted) { // mounted check
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Permessi di localizzazione negati permanentemente. Apri le impostazioni per abilitarli.')));
      }
      // Potresti anche aggiungere un pulsante per aprire le impostazioni dell'app:
      // await Geolocator.openAppSettings();
      return;
    }

    // 3. Se arriviamo qui, i permessi sono concessi. Ottieni la posizione.
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high); // Puoi scegliere l'accuratezza

      setState(() {
        _currentDeviceLocation = LatLng(position.latitude, position.longitude);
      });

      // Muovi la mappa alla nuova posizione
      if (_currentDeviceLocation != null) {
        _mapController.move(_currentDeviceLocation!, 15.0); // 15.0 è un esempio di zoom
        if (mounted) { // mounted check
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Posizione trovata: Lat: ${_currentDeviceLocation!.latitude}, Lng: ${_currentDeviceLocation!.longitude}')));
        }
      }

    } catch (e) {
      if (mounted) { // mounted check
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore nel recuperare la posizione: $e')));
      }
      print('Errore nel recuperare la posizione: $e');
    }
  }
  // --- FINE NUOVO METODO PER LA POSIZIONE ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [ // Aggiungiamo un pulsante per ottenere la posizione nella AppBar
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Trova la mia posizione',
            onPressed: _determineAndGoToCurrentPosition,
          ),
        ],
        toolbarHeight: 40.0,
      ),
      body: Stack(
        children: <Widget>[
          FlutterMap(
            mapController: _mapController, // Assegna il controller alla mappa
            options: MapOptions(
              initialCenter: _currentDeviceLocation ?? const LatLng(51.509865, -0.118092), // Usa la posizione corrente se disponibile, altrimenti default
              initialZoom: _currentDeviceLocation != null ? 15.0 : 9.2, // Zoom diverso se la posizione è nota
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'simone.zanchi.osm_v2',
              ),
              if (_currentDeviceLocation != null) // Mostra un marcatore sulla posizione corrente
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentDeviceLocation!,
                      width: 80,
                      height: 80,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                    ),
                  ],
                ),
            ],
          ),
          if (_showMessage)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

