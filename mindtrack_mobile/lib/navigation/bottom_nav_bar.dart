import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    // Deduct standard margin to build a premium floating nav bar
    final double barWidth = screenWidth - 32;
    final double itemWidth = barWidth / 4;

    // Sizing for our sliding pill capsule
    final double pillWidth = itemWidth * 0.85;
    final double pillHeight = 46;

    final List<Map<String, dynamic>> items = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.book_rounded, 'label': 'Journal'},
      {'icon': Icons.air_rounded, 'label': 'Breathe'},
      {'icon': Icons.person_rounded, 'label': 'Profile'},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.navBarBackground,
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        border: Border.all(color: AppColors.borderOverlay, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 25,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Sliding Pill Capsule Background (behind active item)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            left: (itemWidth * selectedIndex) + (itemWidth - pillWidth) / 2,
            child: Container(
              width: pillWidth,
              height: pillHeight,
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                border: Border.all(
                  color: AppColors.primaryColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
          ),

          // Navigation items clickable overlays
          Row(
            children: List.generate(items.length, (index) {
              final isSelected = index == selectedIndex;
              final item = items[index];

              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onTap(index),
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    child: SizedBox(
                      height: 72,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: isSelected ? 1.15 : 1.0,
                            duration: const Duration(milliseconds: 180),
                            child: Icon(
                              item['icon'] as IconData,
                              color: isSelected
                                  ? AppColors.primaryColor
                                  : AppColors.navBarUnselected,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['label'] as String,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.primaryColor
                                  : AppColors.navBarUnselected,
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
