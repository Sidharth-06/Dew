import 'package:flutter/material.dart';
import 'package:dew/core/theme/aura_colors.dart';
import 'package:go_router/go_router.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AuraColors.white,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ready to play?',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AuraColors.electricViolet,
                    ),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: AuraColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => context.push('/settings'),
              icon:
                  const Icon(Icons.settings_rounded, color: AuraColors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
