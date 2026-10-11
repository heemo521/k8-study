import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../content/models.dart';
import '../content/search.dart';
import '../widgets/page_body.dart';

/// Find a concept, command or flag across the current subject.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final _controller = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentBundle>();
    final query = _controller.text.trim();
    final hits = search(content, query);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: TextField(
          key: const ValueKey('search-field'),
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search ${content.subject.title}',
            border: InputBorder.none,
          ),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          if (query.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close),
              onPressed: () => setState(_controller.clear),
            ),
        ],
      ),
      body: PageList(children: [
        if (query.length < 2)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(
              'Search topics, notes and flashcards — try “taint”, '
              '“etcd snapshot” or “NodePort”.',
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          )
        else if (hits.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text('No matches for “$query”.',
                style: textTheme.bodyMedium, textAlign: TextAlign.center),
          )
        else ...[
          Text('${hits.length}${hits.length == 50 ? '+' : ''} results',
              style: textTheme.labelMedium),
          const SizedBox(height: 8),
          for (final h in hits)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(switch (h.kind) {
                  SearchKind.topic => Icons.menu_book_outlined,
                  SearchKind.section => Icons.article_outlined,
                  SearchKind.flashcard => Icons.style_outlined,
                }),
                title: Text(h.title),
                subtitle: Text(
                  '${h.kind == SearchKind.topic ? 'Topic' : h.topic.title} · ${h.snippet}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => context.go(switch (h.kind) {
                  SearchKind.section =>
                    '/topic/${h.topic.id}/notes?section=${h.sectionId}',
                  SearchKind.flashcard => '/topic/${h.topic.id}/cards',
                  SearchKind.topic => '/topic/${h.topic.id}',
                }),
              ),
            ),
        ],
      ]),
    );
  }
}
