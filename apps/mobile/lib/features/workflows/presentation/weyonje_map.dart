import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class WeyonjeMap extends StatelessWidget {
  const WeyonjeMap({
    required this.destinationLatitude,
    required this.destinationLongitude,
    this.providerLatitude,
    this.providerLongitude,
    this.onSelected,
    this.encodedRoute,
    super.key,
  });

  final double destinationLatitude;
  final double destinationLongitude;
  final double? providerLatitude;
  final double? providerLongitude;
  final ValueChanged<LatLng>? onSelected;
  final String? encodedRoute;

  @override
  Widget build(BuildContext context) {
    final destination = LatLng(destinationLatitude, destinationLongitude);
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        infoWindow: const InfoWindow(title: 'Selected Destination'),
      ),
      if (providerLatitude != null && providerLongitude != null)
        Marker(
          markerId: const MarkerId('provider'),
          position: LatLng(providerLatitude!, providerLongitude!),
          infoWindow: const InfoWindow(title: 'Provider Position'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
    };
    return Semantics(
      label: 'Map. Destination $destinationLatitude, $destinationLongitude.',
      child: SizedBox(
        height: 320,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: destination,
              zoom: 15,
            ),
            markers: markers,
            polylines: encodedRoute == null || encodedRoute!.isEmpty
                ? const <Polyline>{}
                : {
                    Polyline(
                      polylineId: const PolylineId('google-guidance'),
                      points: _decodePolyline(encodedRoute!),
                      color: Theme.of(context).colorScheme.primary,
                      width: 5,
                    ),
                  },
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
            compassEnabled: true,
            onTap: onSelected,
            onCameraIdle: () {},
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
