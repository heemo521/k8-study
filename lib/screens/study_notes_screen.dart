import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../ads/ads_service.dart';
import '../audio/narration.dart';
import '../audio/speech.dart';
import '../content/models.dart';
import '../progress/progress_store.dart';
import '../widgets/note_block_view.dart';
import '../widgets/not_found.dart';
import '../widgets/page_body.dart';
import '../widgets/source_link.dart';

/// S3 — the topic's note sections. A section is marked read when its foot
/// scrolls into view, via "Mark read", or once it has been read aloud.
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
  late final SpeechController _speech = context.read<SpeechController>();
  int? _spokenGroup;
  String? _shownError;

  Topic? get _topic => context.read<ContentBundle>().topic(widget.topicId);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_checkVisible);
    _speech.addListener(_followSpeech);
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

  /// Index of the section the reader is looking at: the last one whose
  /// heading is at or above the upper part of the screen.
  int _visibleSection(Topic topic) {
    var visible = 0;
    for (var i = 0; i < topic.sections.length; i++) {
      final box = _headingKeys[topic.sections[i].id]?.currentContext
          ?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport == null) continue;
      final top = viewport.getOffsetToReveal(box, 0).offset;
      if (top <= _scroll.offset + 120) visible = i;
    }
    return visible;
  }

  /// Starts reading aloud at section [from] (default: the one on screen).
  void _listen(Topic topic, {int? from}) {
    final start = from ?? _visibleSection(topic);
    final progress = context.read<ProgressStore>();
    _speech.onGroupDone = (group) {
      if (group < topic.sections.length) {
        progress.markSectionRead(topic.id, topic.sections[group].id);
      }
    };
    _shownError = null;
    _speech.play(narrateTopic(topic), startGroup: start);
  }

  /// Keeps the section being read on screen, and reports failures.
  void _followSpeech() {
    final error = _speech.error;
    if (error != null && !identical(error, _shownError) && mounted) {
      _shownError = error;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
    final group = _speech.group;
    if (group == _spokenGroup) return;
    _spokenGroup = group;
    final topic = _topic;
    if (group == null || topic == null || group >= topic.sections.length) {
      return;
    }
    _jumpTo(topic.sections[group].id);
  }

  @override
  void dispose() {
    _speech.removeListener(_followSpeech);
    _speech.onGroupDone = null;
    _speech.stop();
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
    final speech = context.watch<SpeechController>();
    final ads = context.read<AdsService>();
    final scheme = Theme.of(context).colorScheme;
    final readCount = progress.readCount(topic);
    final total = topic.sections.length;
    final textTheme = Theme.of(context).textTheme;

    final children = <Widget>[];
    for (var i = 0; i < total; i++) {
      final section = topic.sections[i];
      final isRead = progress.readSections(topic.id).contains(section.id);
      final footerKey = _footerKeys.putIfAbsent(section.id, GlobalKey.new);
      final headingKey = _headingKeys.putIfAbsent(section.id, GlobalKey.new);
      final speaking = speech.group == i;
      children.addAll([
        AnimatedContainer(
          key: headingKey,
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(top: 8, bottom: 8),
          padding: EdgeInsets.only(left: speaking ? 10 : 0),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: speaking ? scheme.primary : Colors.transparent,
                width: speaking ? 4 : 0,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    '${i + 1}. ${section.heading}',
                    style: textTheme.titleLarge,
                  ),
                ),
              ),
              if (speech.supported)
                IconButton(
                  key: ValueKey('listen-${section.id}'),
                  tooltip: 'Listen from here',
                  icon: Icon(
                    speaking ? Icons.graphic_eq : Icons.volume_up_outlined,
                    color: speaking ? scheme.primary : null,
                  ),
                  onPressed: () => _listen(topic, from: i),
                ),
            ],
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
          if (speech.supported)
            IconButton(
              key: const ValueKey('listen'),
              tooltip: 'Listen',
              icon: const Icon(Icons.headphones_outlined),
              onPressed: speech.status == SpeechStatus.idle
                  ? () => _listen(topic)
                  : null,
            ),
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
      // Notes text is selectable so commands and terms can be copied.
      body: SelectionArea(
        child: PageList(controller: _scroll, children: children),
      ),
      bottomNavigationBar: speech.status == SpeechStatus.idle
          ? null
          : _ListenBar(
              speech: speech,
              heading: speech.group == null || speech.group! >= total
                  ? ''
                  : topic.sections[speech.group!].heading,
            ),
    );
  }
}

/// Mini player shown while notes are read aloud.
class _ListenBar extends StatelessWidget {
  const _ListenBar({required this.speech, required this.heading});

  final SpeechController speech;
  final String heading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final playing = speech.status == SpeechStatus.playing;
    final rate = speech.rate;
    String label(double r) =>
        '${r.toStringAsFixed(r == r.roundToDouble() ? 0 : 2).replaceAll(RegExp(r'0$'), '')}×';

    final info = Row(
      children: [
        Icon(Icons.graphic_eq, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                playing ? 'Reading aloud' : 'Paused',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall,
              ),
              Text(
                heading,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
    final controls = [
      IconButton(
        key: const ValueKey('listen-prev'),
        tooltip: 'Previous section',
        icon: const Icon(Icons.skip_previous),
        onPressed: () => speech.skip(-1),
      ),
      IconButton.filledTonal(
        key: const ValueKey('listen-toggle'),
        tooltip: playing ? 'Pause' : 'Resume',
        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
        onPressed: playing ? speech.pause : speech.resume,
      ),
      IconButton(
        key: const ValueKey('listen-next'),
        tooltip: 'Next section',
        icon: const Icon(Icons.skip_next),
        onPressed: () => speech.skip(1),
      ),
      TextButton(
        key: const ValueKey('listen-rate'),
        onPressed: () {
          const rates = SpeechController.rates;
          final i = rates.indexOf(rate);
          speech.setRate(rates[(i + 1) % rates.length]);
        },
        child: Semantics(
          label: 'Speed ${label(rate)}',
          excludeSemantics: true,
          child: Text(label(rate), maxLines: 1),
        ),
      ),
      IconButton(
        key: const ValueKey('listen-stop'),
        tooltip: 'Stop',
        icon: const Icon(Icons.close),
        onPressed: speech.stop,
      ),
    ];

    return Material(
      key: const ValueKey('listen-bar'),
      color: scheme.surfaceContainer,
      elevation: 3,
      child: SafeArea(
        top: false,
        // heightFactor 1: as a bottom bar it must hug its content, not
        // expand to the full screen height.
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              // Phones: title on its own line, controls below, so the
              // section name stays readable. Wider: one row.
              child: LayoutBuilder(
                builder: (context, c) => c.maxWidth < 520
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8, top: 2),
                            child: info,
                          ),
                          Wrap(
                            alignment: WrapAlignment.spaceEvenly,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: controls,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: info),
                          ...controls,
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
