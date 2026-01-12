import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/content_item.dart';
import '../providers/content_provider.dart';

class DetailScreen extends StatelessWidget {
  final ContentItem item;

  const DetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали'),
        actions: [
          IconButton(
            icon: Icon(item.isSaved ? Icons.favorite : Icons.favorite_border),
            onPressed: () {
              context.read<ContentProvider>().toggleSave(item);
            },
          ),
          if (item.postUrl != null)
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              onPressed: () => launchUrl(Uri.parse(item.postUrl!)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CachedNetworkImage(
              imageUrl: item.mediaUrl,
              fit: BoxFit.contain,
              width: double.infinity,
              placeholder: (_, __) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(64),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  if (item.author != null)
                    Text(
                      'Автор: ${item.author}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (item.isGif)
                        const Chip(label: Text('GIF')),
                      if (item.isNsfw)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Chip(
                            label: Text('NSFW'),
                            backgroundColor: Colors.red,
                            labelStyle: TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
