import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dew/API/musify.dart';
import 'package:dew/core/theme/aura_colors.dart';
import 'package:dew/core/widgets/glass_container.dart';
import 'package:dew/main.dart'; // audioHandler
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _isSearching = true;
    });

    try {
      final results = await fetchSongsList(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraColors.deepBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Search',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
              ).animate().fadeIn().slideX(begin: -0.2, end: 0),
              const SizedBox(height: 20),
              // Search Bar
              GlassContainer(
                height: 50,
                width: double.infinity,
                color: AuraColors.surfaceLight,
                opacity: 0.5,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AuraColors.white70),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Songs, Artists, Albums...',
                          hintStyle: TextStyle(color: AuraColors.white38),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon:
                            const Icon(Icons.close, color: AuraColors.white70),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.2, end: 0),
              const SizedBox(height: 20),

              Expanded(
                child:
                    _isSearching ? _buildSearchResults() : _buildCategories(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    final categories = [
      'Pop',
      'Rock',
      'Hip-Hop',
      'Electronic',
      'R&B',
      'Indie',
      'Workout',
      'Chill'
    ];
    final gradients = AuraColors.genreGradients;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Browse All',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.6,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  gradient: gradients[index % gradients.length],
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: gradients[index % gradients.length]
                          .colors
                          .first
                          .withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                        right: -10,
                        bottom: -5,
                        child: RotationTransition(
                          turns: const AlwaysStoppedAnimation(0.05),
                          child: Icon(Icons.music_note,
                              color: Colors.white.withOpacity(0.2), size: 80),
                        )),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        categories[index % categories.length],
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 20),
                      ),
                    ),
                  ],
                ),
              )
                  .animate(delay: (50 * index).ms)
                  .scale(
                      begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack)
                  .fadeIn();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AuraColors.electricViolet));
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'No results found',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: AuraColors.white70),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final song = _searchResults[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Hero(
            tag:
                'search_img_${(song['ytid'] ?? song['title'] ?? song.hashCode).toString()}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: song['image'].toString(),
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Container(color: AuraColors.surfaceLight),
              ),
            ),
          ),
          title: Text(
            song['title'].toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            song['artist'].toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AuraColors.white70),
          ),
          onTap: () {
            // Play song
            audioHandler.playSong(song);
          },
        ).animate(delay: (50 * index).ms).fadeIn().slideX();
      },
    );
  }
}
