/*
 *     Copyright (C) 2024 Valeri Gokadze
 *
 *     Dew is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Dew is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Dew, including how to contribute,
 *     please visit: https://github.com/gokadzev/Dew
 */

import 'package:flutter/material.dart';
import 'package:Dew/extensions/l10n.dart';

class PlaylistHeader extends StatelessWidget {
  PlaylistHeader(
    this.image,
    this.title,
    this.songsLength, {
    super.key,
  });

  final Widget image;
  final String title;
  final int songsLength;

  @override
  Widget build(BuildContext context) {
    final _primaryColor = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        image,
        const SizedBox(width: 10),
        SizedBox(
          width: MediaQuery.of(context).size.width / 2.3,
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                '$songsLength ${context.l10n!.songs}'.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
