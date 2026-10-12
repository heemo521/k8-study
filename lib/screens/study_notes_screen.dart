import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../ads/ads_service.dart';
import '../audio/narration.dart';
import '../audio/speech.dart';
import '../content/models.dart';
import '../progress/progress_store.dart';
import '../widgets/key_handler.dart';
import '../widgets/note_block_view.dart';
import '../widgets/not_found.dart';
import '../widgets/page_body.dart';
import '../widgets/source_link.dart';

/// S3 — the topic's note sections, one page per section. Swipe, tap
/// Next/Back or use the arrow keys to turn pages. A section is marked read
/// when its foot scrolls into view, when the reader moves on with Next, via
/// "Mark read", or once it has been read aloud.
class StudyNotesScreen extends StatefulWidget {
  const StudyNotesScreen({super.key, required this.topicId, this.sectionId});

  final String topicId;

  /// Section to open on (e.g. from search).
  final String? sectionId;

  @override
  State<StudyNotesScreen> createState() => _StudyNotesScreenState();
}

class _StudyNotesScreenState extends State<StudyNotesScreen> {
  late final PageController _pages;
  final Map<String, ScrollController> _scrolls = {};
  final Map<String, GlobalKey> _footerKeys = {};
  late final SpeechController _speech = context.read<SpeechController>();
  int _page = 0;
  int? _spokenGroup;
  String? _shownError;

  Topic? get _topic => context.read<ContentBundle>().topic(widget.topicId);

  @override
  void initState() {
    super.initState();
    final sections = _topic?.sections ?? const <NoteSection>[];
    final start = sections.indexWhere((s) => s.id == widget.sectionId);
    _page = start < 0 ? 0 : start;
    _pages = PageController(initialPage: _page);
    _speech.addListener(_followSpeech);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final topic = _topic;
      if (topic == null || !mounted) return;
      context.read<ProgressStore>().markTopicVisited(
        context.read<ContentBundle>().subject.id,
        topic.id,
      );
      _checkVisible();
    });
  }

  ScrollController _scrollFor(NoteSection section) =>
      _scrolls.putIfAbsent(section.id, () {
        final controller = ScrollController();
        controller.addListener(_checkVisible);
        return controller;
      });

  void _goTo(int page, {bool animate = true}) {
    final topic = _topic;
    if (topic == null || !_pages.hasClients) return;
    final target = page.clamp(0, topic.sections.length - 1);
    if (animate && !MediaQuery.of(context).disableAnimations) {
      _pages.animateToPage(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _pages.jumpToPage(target);
    }
  }

  /// Next: the current section counts as read once the reader moves on.
  void _next(Topic topic) {
    context.read<ProgressStore>().markSectionRead(
      topic.id,
      topic.sections[_page].id,
    );
    if (_page < topic.sections.length - 1) {
      _goTo(_page + 1);
    } else {
      context.go('/topic/${topic.id}/cards');
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final topic = _topic;
    if (topic == null || event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (_page < topic.sections.length - 1) _next(topic);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _goTo(_page - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _showSections(Topic topic) async {
    final read = context.read<ProgressStore>().readSections(topic.id);
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var i = 0; i < topic.sections.length; i++)
              ListTile(
                selected: i == _page,
                leading: Icon(
                  read.contains(topic.sections[i].id)
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                ),
                title: Text('${i + 1}. ${topic.sections[i].heading}'),
                onTap: () => Navigator.pop(sheet, i),
              ),
          ],
        ),
      ),
    );
    if (picked != null) _goTo(picked, animate: false);
  }

  /// Starts reading aloud at section [from] (default: the page on screen).
  void _listen(Topic topic, {int? from}) {
    final start = from ?? _page;
    final progress = context.read<ProgressStore>();
    _speech.onGroupDone = (group) {
      if (group < topic.sections.length) {
        progress.markSectionRead(topic.id, topic.sections[group].id);
      }
    };
    _shownError = null;
    _speech.play(narrateTopic(topic), startGroup: start);
  }

  /// Turns to the page being read, and reports failures.
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
    if (group != _page) _goTo(group);
  }

  @override
  void dispose() {
    _speech.removeListener(_followSpeech);
    _speech.onGroupDone = null;
    _speech.stop();
    _pages.dispose();
    for (final c in _scrolls.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Marks the page's section read once its foot is on screen.
  void _checkVisible() {
    final topic = _topic;
    if (topic == null || !mounted || topic.sections.isEmpty) return;
    final section = topic.sections[_page.clamp(0, topic.sections.length - 1)];
    final progress = context.read<ProgressStore>();
    if (progress.readSections(topic.id).contains(section.id)) return;
    final scroll = _scrolls[section.id];
    final box = _footerKeys[section.id]?.currentContext?.findRenderObject();
    if (scroll == null || !scroll.hasClients) return;
    if (box == null || !box.attached) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    // Scroll offset at which the footer's bottom meets the viewport bottom.
    final revealAt = viewport.getOffsetToReveal(box, 1.0).offset;
    if (scroll.offset >= revealAt - 1) {
      progress.markSectionRead(topic.id, section.id);
    }
  }

  Widget _sectionPage(
    BuildContext context,
    Topic topic,
    int i, {
    required bool isRead,
    required bool speaking,
    required bool canListen,
  }) {
    final section = topic.sections[i];
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progress = context.read<ProgressStore>();
    final ads = context.read<AdsService>();
    final footerKey = _footerKeys.putIfAbsent(section.id, GlobalKey.new);
    return PageList(
      key: PageStorageKey('notes-page-${section.id}'),
      controller: _scrollFor(section),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'PART ${i + 1} OF ${topic.sections.length}',
            style: textTheme.labelMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(top: 2, bottom: 8),
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
                  child: Text(section.heading, style: textTheme.titleLarge),
                ),
              ),
              if (canListen)
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
                      color: scheme.primary,
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
        if (i == 1 && topic.sections.length >= 3) ...[
          const SizedBox(height: 12),
          ads.banner(AdPlacement.studyNotesBanner),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final topic = _topic;
    if (topic == null) return const NotFoundView(message: 'Topic not found.');
    final progress = context.watch<ProgressStore>();
    final speech = context.watch<SpeechController>();
    final readCount = progress.readCount(topic);
    final total = topic.sections.length;
    final textTheme = Theme.of(context).textTheme;
    final read = progress.readSections(topic.id);

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
      body: KeyHandler(
        onKey: _onKey,
        child: SelectionArea(
          child: PageView.builder(
            key: const ValueKey('notes-pages'),
            controller: _pages,
            itemCount: total,
            onPageChanged: (i) {
              setState(() => _page = i);
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _checkVisible(),
              );
            },
            itemBuilder: (context, i) => _sectionPage(
              context,
              topic,
              i,
              isRead: read.contains(topic.sections[i].id),
              speaking: speech.group == i,
              canListen: speech.supported,
            ),
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (speech.status != SpeechStatus.idle)
            _ListenBar(
              speech: speech,
              heading: speech.group == null || speech.group! >= total
                  ? ''
                  : topic.sections[speech.group!].heading,
            ),
          _PageNav(
            page: _page,
            total: total,
            read: [for (final s in topic.sections) read.contains(s.id)],
            onBack: _page == 0 ? null : () => _goTo(_page - 1),
            onNext: () => _next(topic),
            onDot: (i) => _goTo(i),
          ),
        ],
      ),
    );
  }
}

/// Back / page dots / Next under the notes. On the last page Next leads to
/// the flashcards.
class _PageNav extends StatelessWidget {
  const _PageNav({
    required this.page,
    required this.total,
    required this.read,
    required this.onBack,
    required this.onNext,
    required this.onDot,
  });

  final int page;
  final int total;
  final List<bool> read;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final ValueChanged<int> onDot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = page >= total - 1;
    return Material(
      key: const ValueKey('notes-nav'),
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                children: [
                  Flexible(
                    child: TextButton.icon(
                      key: const ValueKey('notes-back'),
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back', overflow: TextOverflow.fade),
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      label: 'Part ${page + 1} of $total',
                      excludeSemantics: true,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          for (var i = 0; i < total; i++)
                            InkWell(
                              key: ValueKey('notes-dot-$i'),
                              customBorder: const CircleBorder(),
                              onTap: () => onDot(i),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: i == page ? 18 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: i == page
                                        ? scheme.primary
                                        : read[i]
                                        ? scheme.primary.withValues(alpha: 0.45)
                                        : scheme.outlineVariant,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    flex: last ? 2 : 1,
                    child: FilledButton.icon(
                      key: ValueKey(last ? 'next-flashcards' : 'notes-next'),
                      onPressed: onNext,
                      icon: const Icon(Icons.arrow_forward),
                      iconAlignment: IconAlignment.end,
                      label: Text(
                        last ? 'Flashcards' : 'Next',
                        overflow: TextOverflow.fade,
                        softWrap: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
