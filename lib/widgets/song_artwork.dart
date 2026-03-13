/*
 *     Copyright (C) 2024 Valeri Gokadze
 *
 *     dew is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     dew is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about dew, including how to contribute,
 *     please visit: https://github.com/gokadzev/dew
 */

import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:dew/widgets/no_artwork_cube.dart';
import 'package:dew/widgets/spinner.dart';

class SongArtworkWidget extends StatelessWidget {
  const SongArtworkWidget({
    super.key,
    required this.size,
    required this.metadata,
    this.borderRadius = 10.0,
    this.errorWidgetIconSize = 20.0,
    this.fit = BoxFit.cover, // Default value for fit
  });

  final double size;
  final MediaItem metadata;
  final double borderRadius;
  final double errorWidgetIconSize;
  final BoxFit fit; // Added fit parameter

  @override
  Widget build(BuildContext context) {
    // Prefer explicit local artwork path in extras when available
    final extraArtwork = metadata.extras?['artWorkPath']?.toString();
    if (extraArtwork != null && extraArtwork.isNotEmpty) {
      final file = File(extraArtwork);
      if (file.existsSync()) {
        return SizedBox(
          width: size,
          height: size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.file(
              file,
              fit: fit,
            ),
          ),
        );
      }
    }

    // Normalize artUri if present and valid
    final uri = metadata.artUri;
    final String? uriStr = uri?.toString();

    if (uri != null && uriStr != null && uriStr.isNotEmpty && uriStr.toLowerCase() != 'null') {
      // Handle file:// URIs if not already covered by extras
      if (uri.scheme == 'file') {
        try {
          final path = uri.toFilePath();
          final file = File(path);
          if (file.existsSync()) {
            return SizedBox(
              width: size,
              height: size,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: Image.file(
                  file,
                  fit: fit,
                ),
              ),
            );
          }
        } catch (_) {
          // Fall through to network handling
        }
      }

      // If it's an HTTP(S) resource, try network image
      if (uri.isScheme('http') || uri.isScheme('https')) {
        return CachedNetworkImage(
          width: size,
          height: size,
          imageUrl: uriStr,
          imageBuilder: (context, imageProvider) => ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image(
              image: imageProvider,
              fit: fit,
            ),
          ),
          placeholder: (context, url) => const Spinner(),
          errorWidget: (context, url, error) => NullArtworkWidget(
            iconSize: errorWidgetIconSize,
          ),
        );
      }
    }

    // Fallback to lowResImage in extras
    final lowRes = metadata.extras?['lowResImage']?.toString();
    if (lowRes != null && lowRes.isNotEmpty && lowRes.toLowerCase() != 'null') {
      return CachedNetworkImage(
        width: size,
        height: size,
        imageUrl: lowRes,
        imageBuilder: (context, imageProvider) => ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image(
            image: imageProvider,
            fit: fit,
          ),
        ),
        placeholder: (context, url) => const Spinner(),
        errorWidget: (context, url, error) => NullArtworkWidget(
          iconSize: errorWidgetIconSize,
        ),
      );
    }

    // No valid artwork found — show placeholder
    return NullArtworkWidget(iconSize: errorWidgetIconSize, size: size);
  }
}
