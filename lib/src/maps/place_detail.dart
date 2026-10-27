import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../theme/brand_tokens.dart';

/// Fetches the most useful fields from the gateway's place-details proxy.
Future<Map<String, dynamic>> fetchPlaceDetails({
  required String placeName,
  required double lat,
  required double lng,
}) async {
  final base = AppConfig.gatewayBaseUrl;
  final uri = Uri.parse('$base/api/v1/places/details').replace(
    queryParameters: {
      'place_name': placeName,
      'fields':
          'name,formatted_address,formatted_phone_number,rating,reviews,photos',
    },
  );

  final resp = await http.get(uri);
  if (resp.statusCode != 200) return {};

  final data = jsonDecode(resp.body);
  if (data['status'] != 'OK') return {};

  return data['result'] as Map<String, dynamic>;
}

/// Returns a direct photo URL from a photo_reference via the gateway proxy.
Future<String> fetchPhotoUrl({
  required String photoRef,
  required int maxWidth,
}) async {
  final base = AppConfig.gatewayBaseUrl;
  final uri = Uri.parse('$base/api/v1/places/photo').replace(
    queryParameters: {
      'maxwidth': maxWidth.toString(),
      'photo_name': photoRef,
    },
  );
  final resp = await http.get(uri);
  if (resp.statusCode == 200) {
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final photoData = data['photo_data'] as String?;
    return photoData ?? '';
  }
  return '';
}

/// A tiny bottom-sheet that shows address, phone, rating and a photo carousel.
class PlaceDetailBottomSheet extends StatelessWidget {
  final Map<String, dynamic> details;
  const PlaceDetailBottomSheet({required this.details, super.key});

  @override
  Widget build(BuildContext context) {
    final palette = KarumPalette.of(context);
    final rating = details['rating']?.toDouble() ?? 0.0;
    final List<dynamic> reviews = details['reviews'] ?? [];
    final List<String> reviewExcerpts = reviews
        .take(3)
        .map((r) {
          final text = r['text'];
          if (text is! String || text.isEmpty) return '';
          return text.substring(0, text.length < 60 ? text.length : 60);
        })
        .toList();

    Widget? photoWidget;
    if (details['photos']?.isNotEmpty == true) {
      final ref = details['photos'][0]['name'];
      photoWidget = FutureBuilder<String>(
        future: fetchPhotoUrl(photoRef: ref, maxWidth: 400),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          }
          if (snap.hasError || snap.data == null || snap.data!.isEmpty) {
            return const Icon(Icons.image, size: 64);
          }
          return Image.network(
            snap.data!,
            width: 200,
            height: 150,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => const Icon(Icons.image, size: 64),
          );
        },
      );
    } else {
      photoWidget = const Icon(Icons.image, size: 64);
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(KarumSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            photoWidget,
            const SizedBox(height: KarumSpacing.md),
            Text(
              details['formatted_address'] ?? 'Address unknown',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: KarumSpacing.sm),
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: palette.ink),
                const SizedBox(width: 4),
                Text(
                  details['formatted_phone_number'] ?? 'No phone',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: KarumSpacing.sm),
            Row(
              children: [
                Icon(Icons.star, color: palette.brand, size: 16),
                const SizedBox(width: 4),
                Text(rating.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: KarumSpacing.sm),
            ...reviewExcerpts.map((txt) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                txt,
                style:
                    Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.mute),
              ),
            ))
          ],
        ),
      ),
    );
  }
}