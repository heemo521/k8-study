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
  const StudyNotesScreen({super.key, required this.topicId, this.sectionId});

  final String topicId;

  /// Section to scroll to on open (e.g. from search).
  final String? sectionId;

  @override
  State<StudyNotesScreen> createState() => _StudyNotesScreenState();
}

class _StudyNotesScreenState extends State<StudyNotesScreen> {
  final _scroll = ScrollController();
  final Map<String, GlobalKey> _footerKeys = {};
  final Map<String, GlobalKey> _headingKeys = {};

  Topic? get _topic => context.read<ContentBundle>().topic(widget.topicId);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_checkVisible);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final topic = _topic;
      if (topic == null || !mounted) return;
      context.read<ProgressStore>().markTopicVisited(
        context.read<ContentBundle>().subject.id,
        topic.id,
      );
      if (widget.sectionId != null) {
        _jumpTo(widget.sectionId!);
      } else {
        _checkVisible();
      }
    });
  }

  void _jumpTo(String sectionId) {
    final ctx = _headingKeys[sectionId]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 250),
      alignment: 0.02,
    );
  }

  Future<void> _showSections(Topic topic) async {
    final read = context.read<ProgressStore>().readSections(topic.id);
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var i = 0; i < topic.sections.length; i++)
              ListTile(
                leading: Icon(
                  read.contains(topic.sections[i].id)
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                ),
                title: Text('${i + 1}. ${topic.sections[i].heading}'),
                onTap: () => Navigator.pop(sheet, topic.sections[i].id),
              ),
          ],
        ),
      ),
    );
    if (picked != null) _jumpTo(picked);
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
      final headingKey = _headingKeys.putIfAbsent(section.id, GlobalKey.new);
      children.addAll([
        Padding(
          key: headingKey,
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Semantics(
            header: true,
            child: Text(
              '${i + 1}. ${section.heading}',
              style: textTheme.titleLarge,
            ),
          ),
        ),
        for (final block in section.blocks) NoteBlockView(block),
        Row(
          key: footerKey,
          children: [
            Expanded(
              child: SourceLink(
                url: section.sourceUrl,
                title: section.sourceTitle,
              ),
            ),
            isRead
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                      semanticLabel: 'Read',
                    ),
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
        actions: [
          IconButton(
            key: const ValueKey('sections-menu'),
            tooltip: 'Sections',
            icon: const Icon(Icons.toc),
            onPressed: () => _showSections(topic),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: total == 0 ? 1 : readCount / total,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                Text('$readCount/$total', style: textTheme.labelMedium),
              ],
            ),
          ),
        ),
      ),
      body: PageList(controller: _scroll, children: children),
    );
  }
}
