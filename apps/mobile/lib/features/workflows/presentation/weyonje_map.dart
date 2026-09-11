import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class WeyonjeMap extends StatefulWidget {
  const WeyonjeMap({
    required this.destinationLatitude,
    required this.destinationLongitude,
    this.providerLatitude,
    this.providerLongitude,
    this.onSelected,
    this.encodedRoute,
    this.hasDestination = true,
    this.showDeviceLocation = true,
    super.key,
  });

  final double destinationLatitude;
  final double destinationLongitude;
  final double? providerLatitude;
  final double? providerLongitude;
  final ValueChanged<LatLng>? onSelected;
  final String? encodedRoute;
  final bool hasDestination;
  final bool showDeviceLocation;

  @override
  State<WeyonjeMap> createState() => _WeyonjeMapState();
}

class _WeyonjeMapState extends State<WeyonjeMap> {
  GoogleMapController? _controller;
  Timer? _loadTimer;
  bool _created = false;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _loadTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && !_created) setState(() => _timedOut = true);
    });
  }

  @override
  void didUpdateWidget(WeyonjeMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasDestination &&
        (oldWidget.destinationLatitude != widget.destinationLatitude ||
            oldWidget.destinationLongitude != widget.destinationLongitude)) {
      _controller?.moveCamera(
        CameraUpdate.newLatLng(
          LatLng(widget.destinationLatitude, widget.destinationLongitude),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _loadTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destinationLatitude = widget.destinationLatitude;
    final destinationLongitude = widget.destinationLongitude;
    final providerLatitude = widget.providerLatitude;
    final providerLongitude = widget.providerLongitude;
    final encodedRoute = widget.encodedRoute;
    final onSelected = widget.onSelected;
    final destination = LatLng(destinationLatitude, destinationLongitude);
    final markers = <Marker>{
      if (widget.hasDestination)
        Marker(
          markerId: const MarkerId('destination'),
          position: destination,
          infoWindow: const InfoWindow(title: 'Selected Destination'),
        ),
      if (providerLatitude != null && providerLongitude != null)
        Marker(
          markerId: const MarkerId('provider'),
          position: LatLng(providerLatitude, providerLongitude),
          infoWindow: const InfoWindow(title: 'Provider Position'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
    };
    return Semantics(
      label: widget.hasDestination
          ? 'Map. Destination $destinationLatitude, $destinationLongitude.'
          : 'Map. No service location selected.',
      child: SizedBox(
        height: 320,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: destination,
                  zoom: 15,
                ),
                markers: markers,
                polylines: encodedRoute == null || encodedRoute.isEmpty
                    ? const <Polyline>{}
                    : {
                        Polyline(
                          polylineId: const PolylineId('google-guidance'),
                          points: _decodePolyline(encodedRoute),
                          color: Theme.of(context).colorScheme.primary,
                          width: 5,
                        ),
                      },
                onMapCreated: (controller) {
                  _controller = controller;
                  _loadTimer?.cancel();
                  if (mounted) setState(() => _created = true);
                },
                myLocationButtonEnabled: widget.showDeviceLocation,
                myLocationEnabled: widget.showDeviceLocation,
                compassEnabled: true,
                onTap: onSelected,
                onCameraIdle: () {},
              ),
              if (!_created)
                IgnorePointer(
                  child: Center(
                    child: FCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _timedOut
                            ? const Text(
                                'Map did not initialize. Check your connection and reload the map.',
                              )
                            : const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FCircularProgress(),
                                  SizedBox(height: 8),
                                  Text('Loading Google Map…'),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

List<LatLng> _decodePolyline(String encoded) {
  final points = <LatLng>[];
  var index = 0;
  var latitude = 0;
  var longitude = 0;
  while (index < encoded.length) {
    var result = 0;
    var shift = 0;
    int byte;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20 && index < encoded.length);
    latitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;
    result = 0;
    shift = 0;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20 && index < encoded.length);
    longitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;
    points.add(LatLng(latitude / 1e5, longitude / 1e5));
  }
  return points;
}
