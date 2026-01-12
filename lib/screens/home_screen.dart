import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/content_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🐾 Furry Hub'), actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => context.read<ContentProvider>().fetchContent(),
        ),
      ]),
      body: Consumer<ContentProvider>(
        builder: (context, contentProv, child) => contentProv.loading
            ? const Center(child: CircularProgressIndicator())
            : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1,
                ),
                itemCount: contentProv.contents.length,
                itemBuilder: (context, i) {
                  final item = contentProv.contents[i];
                  return GestureDetector(
                    onTap: () {},  // TODO: FullViewScreen
                    child: Stack(
                      children: [
                        CachedNetworkImage(
                          imageUrl: item.thumbnailUrl ?? item.imageUrl,
                          fit: BoxFit.cover,
                        ),
                        if (item.isNsfw)
                          const Positioned(
                            top: 4,
                            right: 4,
                            child: Icon(Icons.warning, color: Colors.red),
                          ),
                        if (item.isGif)
                          const Positioned(
                            bottom: 4,
                            left: 4,
                            child: Icon(Icons.gif, color: Colors.yellow),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
      bottomNavigationBar: const NavigationBar(
        destinations: [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.source), label: 'Sources'),
          NavigationDestination(icon: Icon(Icons.favorite), label: 'Favorites'),
          NavigationDestination(icon: Icon(Icons.list), label: 'Logs'),
        ],
      ),
    );
  }
}
