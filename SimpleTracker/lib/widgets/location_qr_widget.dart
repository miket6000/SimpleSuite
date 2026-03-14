import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationQrWidget extends StatefulWidget {
  final double? latitude;
  final double? longitude;

  const LocationQrWidget({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<LocationQrWidget> createState() => _LocationQrWidgetState();
}

class _LocationQrWidgetState extends State<LocationQrWidget> {
  String? _lastValidLatitude;
  String? _lastValidLongitude;

  @override
  void didUpdateWidget(covariant LocationQrWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only update last valid location if both latitude and longitude are non-null
    if (widget.latitude != null && widget.longitude != null) {
      _lastValidLatitude = widget.latitude!.toStringAsFixed(5);
      _lastValidLongitude = widget.longitude!.toStringAsFixed(5);
    }
  }

  String? get _googleMapsUrl {
    if (_lastValidLatitude == null || _lastValidLongitude == null) return null;
    return 'https://www.google.com/maps/search/?api=1&query=$_lastValidLatitude,$_lastValidLongitude';
  }

  Future<void> _launchUrl() async {
    final url = _googleMapsUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _googleMapsUrl;

    if (url == null) {
      return const Center(
        child: Text(
          'No location provided',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          onTap: _launchUrl,
          child: QrImageView(
            data: url,
            version: QrVersions.auto,
            size: 200.0,
            backgroundColor: Colors.white,
          ),
        ),

        const SizedBox(height: 8),
        Text(
          'Click or scan to open in Maps',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
