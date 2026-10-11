import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../content/models.dart';
import '../progress/progress_store.dart';

/// App-bar title showing the current subject. With more than one subject in
/// the catalog it becomes a button that opens a subject picker.
class SubjectTitle extends StatelessWidget {
  const SubjectTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<Catalog>();
    final current = context.watch<ContentBundle>();
    if (catalog.subjects.length < 2) {
      return Text('K8 Study · ${current.subject.title}');
    }
    return InkWell(
      key: const ValueKey('subject-switcher'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => showSubjectPicker(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                current.subject.title,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

Future<void> showSubjectPicker(BuildContext context) {
  final catalog = context.read<Catalog>();
  final progress = context.read<ProgressStore>();
  final current = context.read<ContentBundle>().subject.id;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Choose a subject',
              style: Theme.of(sheet).textTheme.titleMedium,
            ),
          ),
          for (final s in catalog.subjects)
            ListTile(
              key: ValueKey('subject-${s.subject.id}'),
              selected: s.subject.id == current,
              title: Text(s.subject.title),
              subtitle: Text(
                '${s.subject.tagline} · '
                '${s.topics.where(progress.topicComplete).length}/${s.topics.length} topics complete',
              ),
              trailing: s.subject.id == current
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                progress.subjectId = s.subject.id;
                Navigator.pop(sheet);
              },
            ),
        ],
      ),
    ),
  );
}
