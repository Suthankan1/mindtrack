import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/dio_service.dart';
import '../theme/app_theme.dart';

class TherapistsScreen extends ConsumerStatefulWidget {
  const TherapistsScreen({super.key});

  @override
  ConsumerState<TherapistsScreen> createState() => _TherapistsScreenState();
}

class _TherapistsScreenState extends ConsumerState<TherapistsScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allTherapists = [];
  List<dynamic> _filteredTherapists = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedSpecialty = 'All';
  String _selectedLocation = 'All';

  final List<String> _specialties = [
    'All',
    'CBT',
    'Anxiety',
    'Depression',
    'Mindfulness',
    'ADHD',
    'Somatic',
    'Trauma',
    'Neurodiversity',
  ];
  final List<String> _locations = ['All', 'New York', 'Colombo', 'Mumbai', 'Remote'];

  @override
  void initState() {
    super.initState();
    _fetchTherapists();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTherapists() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(dioServiceProvider);
      final list = await dio.getTherapists();
      if (mounted) {
        setState(() {
          _allTherapists = list;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('TherapistsScreen error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to secure connection with clinical directories.';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredTherapists = _allTherapists.where((therapist) {
        final name = (therapist['name'] as String? ?? '').toLowerCase();
        final specialty = (therapist['specialty'] as String? ?? '').toLowerCase();
        final location = (therapist['location'] as String? ?? '').toLowerCase();
        
        final List<dynamic> tagsList = therapist['tags'] ?? [];
        final tags = tagsList.map((t) => t.toString().toLowerCase()).toList();

        // Search Query matches name, specialty, or tags
        final matchesSearch = _searchQuery.isEmpty ||
            name.contains(_searchQuery.toLowerCase()) ||
            specialty.contains(_searchQuery.toLowerCase()) ||
            tags.any((t) => t.contains(_searchQuery.toLowerCase()));

        // Specialty filter matches tags or specialty
        final matchesSpecialty = _selectedSpecialty == 'All' ||
            specialty.contains(_selectedSpecialty.toLowerCase()) ||
            tags.any((t) => t == _selectedSpecialty.toLowerCase());

        // Location filter matches location
        final matchesLocation = _selectedLocation == 'All' ||
            location.contains(_selectedLocation.toLowerCase());

        return matchesSearch && matchesSpecialty && matchesLocation;
      }).toList();
    });
  }

  LinearGradient _parseGradient(String gradientStr) {
    final str = gradientStr.toLowerCase();
    if (str.contains('teal') && str.contains('emerald')) {
      return const LinearGradient(
        colors: [Color(0xFF00D2C8), Color(0xFF10B981)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (str.contains('cyan') && str.contains('indigo')) {
      return const LinearGradient(
        colors: [Color(0xFF06B6D4), Color(0xFF6366F1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (str.contains('amber') && str.contains('orange')) {
      return const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (str.contains('purple') && str.contains('pink')) {
      return const LinearGradient(
        colors: [Color(0xFFA855F7), Color(0xFFEC4899)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (str.contains('rose') && str.contains('red')) {
      return const LinearGradient(
        colors: [Color(0xFFF43F5E), Color(0xFFEF4444)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (str.contains('indigo') && str.contains('purple')) {
      return const LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (str.contains('emerald') && str.contains('teal')) {
      return const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF0D9488)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (str.contains('blue') && str.contains('cyan')) {
      return const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (str.contains('amber') && str.contains('red')) {
      return const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (str.contains('fuchsia') && str.contains('pink')) {
      return const LinearGradient(
        colors: [Color(0xFFD946EF), Color(0xFFEC4899)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return const LinearGradient(
      colors: [Color(0xFF00D2C8), Color(0xFF6366F1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Clinical Directory',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: AppColors.borderOverlay,
            height: 1.0,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Scrollable directory configurations
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SDG 3 Banner Card
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF4C9F38).withValues(alpha: 0.3)),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.surfaceColor,
                            const Color(0xFF4C9F38).withValues(alpha: 0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF4C9F38),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4C9F38).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'SDG 3',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'UN SDG 3: Good Health & Well-Being',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Supporting global emotional welfare by connecting patients directly to verified practitioners.',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Search input bar
                    TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                          _applyFilters();
                        });
                      },
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search style, name, or tags...',
                        hintStyle: const TextStyle(color: AppColors.navBarUnselected, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: AppColors.navBarUnselected),
                        fillColor: AppColors.surfaceColor,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.borderOverlay),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.borderOverlay),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Specialty filter chips
                    const Text(
                      'SPECIALTY FILTER',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _specialties.length,
                        itemBuilder: (context, index) {
                          final spec = _specialties[index];
                          final isSelected = _selectedSpecialty == spec;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            key: ValueKey(spec),
                            child: FilterChip(
                              label: Text(spec),
                              selected: isSelected,
                              showCheckmark: false,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.black : AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              selectedColor: AppColors.primaryColor,
                              backgroundColor: AppColors.surfaceColor,
                              side: BorderSide(
                                color: isSelected ? AppColors.primaryColor : AppColors.borderOverlay,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  _selectedSpecialty = spec;
                                  _applyFilters();
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Location filter chips
                    const Text(
                      'LOCATION FILTER',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _locations.length,
                        itemBuilder: (context, index) {
                          final loc = _locations[index];
                          final isSelected = _selectedLocation == loc;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            key: ValueKey(loc),
                            child: FilterChip(
                              label: Text(loc),
                              selected: isSelected,
                              showCheckmark: false,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.black : AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              selectedColor: AppColors.errorColor,
                              backgroundColor: AppColors.surfaceColor,
                              side: BorderSide(
                                color: isSelected ? AppColors.errorColor : AppColors.borderOverlay,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  _selectedLocation = loc;
                                  _applyFilters();
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Directory records list
                    if (_isLoading)
                      const _DirectoryShimmerLoading()
                    else if (_errorMessage != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.errorColor, size: 40),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _fetchTherapists,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryColor,
                                  foregroundColor: AppColors.backgroundColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_filteredTherapists.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Text(
                            'No matching clinical practitioners found.',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredTherapists.length,
                        itemBuilder: (context, index) {
                          final therapist = _filteredTherapists[index];
                          final gradient = _parseGradient(therapist['avatarGradient'] ?? '');
                          final double rating = (therapist['rating'] as num? ?? 5.0).toDouble();
                          final bool verified = therapist['verified'] == true;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.borderOverlay),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top avatar/name row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: gradient,
                                      ),
                                      child: Center(
                                        child: Text(
                                          (therapist['name'] as String? ?? 'PT')
                                              .split(' ')
                                              .filter((n) => !n.contains('.'))
                                              .map((n) => n[0])
                                              .join(''),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  therapist['name'] ?? '',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              if (verified) ...[
                                                const SizedBox(width: 6),
                                                const Icon(
                                                  Icons.verified,
                                                  color: AppColors.primaryColor,
                                                  size: 16,
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryColor.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.15)),
                                            ),
                                            child: Text(
                                              (therapist['specialty'] ?? '').toString().toUpperCase(),
                                              style: const TextStyle(
                                                color: AppColors.primaryColor,
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.star, color: Colors.amber, size: 14),
                                            const SizedBox(width: 3),
                                            Text(
                                              rating.toStringAsFixed(1),
                                              style: const TextStyle(
                                                color: Colors.amber,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              width: 5,
                                              height: 5,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Color(0xFF00D2C8),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              therapist['availability'] ?? 'Available',
                                              style: const TextStyle(
                                                color: Color(0xFF00D2C8),
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                
                                // Bio paragraph
                                Text(
                                  therapist['bio'] ?? '',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11.5,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Tags row
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: (therapist['tags'] as List<dynamic>? ?? []).map((tag) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.borderOverlay.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.borderOverlay.withValues(alpha: 0.5)),
                                      ),
                                      child: Text(
                                        tag.toString(),
                                        style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 16),
                                
                                // Card Footer: location and action
                                const Divider(color: AppColors.borderOverlay, height: 1),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.pin_drop, color: AppColors.errorColor, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          therapist['location'] ?? '',
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                    GestureDetector(
                                      onTap: () async {
                                        final email = therapist['contactEmail'] as String? ?? '';
                                        if (email.isNotEmpty) {
                                          final Uri emailUri = Uri(
                                            scheme: 'mailto',
                                            path: email,
                                            queryParameters: {'subject': 'MindTrack Consultation Request'},
                                          );
                                          await launchUrl(emailUri);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryColor,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primaryColor.withValues(alpha: 0.25),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Text(
                                          'CONTACT',
                                          style: TextStyle(
                                            color: AppColors.backgroundColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectoryShimmerLoading extends StatelessWidget {
  const _DirectoryShimmerLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(4, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 160,
          decoration: BoxDecoration(
            color: AppColors.surfaceColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderOverlay),
          ),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: AppColors.primaryColor, strokeWidth: 1.5),
            ),
          ),
        );
      }),
    );
  }
}

// Extends List to provide custom filtering support
extension _ListFilter<T> on List<T> {
  List<T> filter(bool Function(T) test) {
    final list = <T>[];
    for (var element in this) {
      if (test(element)) {
        list.add(element);
      }
    }
    return list;
  }
}
