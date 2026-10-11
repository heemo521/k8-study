import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../ads/ads_service.dart';
import '../content/models.dart';
import '../progress/progress_store.dart';
import '../widgets/note_block_view.dart';
import '../widgets/not_found.dart';
import '../widgets/page_body.dart';
import '../widgets/source_link.dart';

/// S3 — the topic's note sections. A section is marked read when its foot
/// scrolls into view, or via "Mark read".
class StudyNotesScreen extends StatefulWidget {
  const StudyNotesScreen({super.key, required this.topicId});

  final String topicId;

  @override
  State<StudyNotesScreen> createState() => _StudyNotesScreenState();
}

class _StudyNotesScreenState extends State<StudyNotesScreen> {
  final _scroll = ScrollController();
  final Map<String, GlobalKey> _footerKeys = {};

  Topic? get _topic => context.read<ContentBundle>().topic(widget.topicId);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_checkVisible);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisible());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _checkVisible() {
    final topic = _topic;
    if (topic == null || !mounted || !_scroll.hasClients) return;
    final progress = context.read<ProgressStore>();
    final read = progress.readSections(topic.id);
    for (final section in topic.sections) {
      if (read.contains(section.id)) continue;
      final box = _footerKeys[section.id]?.currentContext?.findRenderObject();
      if (box == null || !box.attached) continue;
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport == null) continue;
      // Scroll offset at which the footer's bottom meets the viewport bottom.
      final revealAt = viewport.getOffsetToReveal(box, 1.0).offset;
      if (_scroll.offset >= revealAt - 1) {
        progress.markSectionRead(topic.id, section.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topic = _topic;
    if (topic == null) return const NotFoundView(message: 'Topic not found.');
    final progress = context.watch<ProgressStore>();
    final ads = context.read<AdsService>();
    final readCount = progress.readCount(topic);
    final total = topic.sections.length;
    final textTheme = Theme.of(context).textTheme;

    final children = <Widget>[];
    for (var i = 0; i < total; i++) {
      final section = topic.sections[i];
      final isRead = progress.readSections(topic.id).contains(section.id);
      final footerKey = _footerKeys.putIfAbsent(section.id, GlobalKey.new);
      children.addAll([
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Semantics(
            header: true,
            child: Text('${i + 1}. ${section.heading}',
                style: textTheme.titleLarge),
          ),
        ),
        for (final block in section.blocks) NoteBlockView(block),
        Row(
          key: footerKey,
          children: [
            Expanded(
              child: SourceLink(url: section.sourceUrl, title: section.sourceTitle),
            ),
            isRead
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                        semanticLabel: 'Read'),
                  )
                : TextButton(
                    key: ValueKey('mark-read-${section.id}'),
                    onPressed: () =>
                        progress.markSectionRead(topic.id, section.id),
                    child: const Text('Mark read'),
                  ),
          ],
        ),
        const Divider(height: 24),
      ]);
      if (i == 1 && total >= 3) {
        children.add(ads.banner(AdPlacement.studyNotesBanner));
      }
    }
    children.add(
      FilledButton.icon(
        key: const ValueKey('next-flashcards'),
        onPressed: () => context.go('/topic/${topic.id}/cards'),
        icon: const Icon(Icons.arrow_forward),
        label: const Text('Next: Flashcards'),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(topic.title),
        leading: BackButton(onPressed: () => context.go('/topic/${topic.id}')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: total == 0 ? 1 : readCount / total,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Text('$readCount/$total', style: textTheme.labelMedium),
            ]),
          ),
        ),
      ),
      body: PageList(controller: _scroll, children: children),
    );
  }
}
