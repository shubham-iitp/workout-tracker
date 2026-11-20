import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/set_row.dart';
import '../../widgets/stepper_button.dart';

class DayEditorScreen extends ConsumerWidget {
  const DayEditorScreen({super.key, required this.dayId});

  final int dayId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider);
    final day = plan.when(
      data: (days) => days.where((d) => d.id == dayId).firstOrNull,
      loading: () => null,
      error: (_, _) => null,
    );
    final dao = ref.read(planDaoProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(day?.name ?? 'Day'),
        actions: [
          if (day != null)
            IconButton(
              tooltip: 'Rename day',
              icon: const Icon(Icons.drive_file_rename_outline),
              onPressed: () async {
                final name = await promptText(
                  context,
                  title: 'Rename day',
                  initial: day.name,
                );
                if (name != null) await dao.renameDay(day.id, name);
              },
            ),
        ],
      ),
      body: AsyncView(
        value: plan,
        builder: (_) {
          if (day == null) {
            return const Center(child: Text('This day no longer exists.'));
          }
          return _DayEditorBody(day: day);
        },
      ),
    );
  }
}

class _DayEditorBody extends ConsumerWidget {
  const _DayEditorBody({required this.day});

  final DayPlan day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.read(planDaoProvider);

    Future<void> addBodyPart() async {
      final name = await promptText(
        context,
        title: 'Add body part',
        label: 'Body part (e.g. Chest)',
        confirm: 'Add',
      );
      if (name == null) return;
      final partId = await dao.addBodyPart(day.id, name);
      if (context.mounted) {
        await showAddExerciseSheet(context, ref, partId, name);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        if (day.isEmpty) _EmptyState(onAddBodyPart: addBodyPart),
        _RoutineSection(day: day, kind: RoutineKind.warmup),
        SectionHeader(
          'Workout',
          subtitle: day.exerciseCount == 0
              ? 'Add a body part, then its exercises'
              : '${plural(day.exerciseCount, 'exercise')} · ${plural(day.setCount, 'set')}',
        ),
        for (final part in day.parts) ...[
          _BodyPartCard(part: part),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: addBodyPart,
          icon: const Icon(Icons.add),
          label: const Text('Add body part'),
        ),
        _RoutineSection(day: day, kind: RoutineKind.cooldown),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddBodyPart});

  final VoidCallback onAddBodyPart;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.dark,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.fitness_center, color: t.accent, size: 32),
          const SizedBox(height: 10),
          Text(
            'Set up this day',
            style: TextStyle(
              fontFamily: headingFont,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: t.onDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add the body parts you train (e.g. Chest, Triceps), then their '
            'exercises and sets. Warm-up and cool-down are optional.',
            style: TextStyle(color: t.onDark.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAddBodyPart,
            icon: const Icon(Icons.add),
            label: const Text('Add body part'),
          ),
        ],
      ),
    );
  }
}

// ---- Warm-up / cool-down ------------------------------------------------------

class _RoutineSection extends ConsumerWidget {
  const _RoutineSection({required this.day, required this.kind});

  final DayPlan day;
  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final items = kind == RoutineKind.warmup ? day.warmups : day.cooldowns;
    final title = kind == RoutineKind.warmup ? 'Warm-up' : 'Cool-down';
    final dao = ref.read(planDaoProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title,
          subtitle: items.isEmpty ? 'Optional — skipped when empty' : null,
        ),
        for (final item in items) ...[
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.only(left: 16, right: 4),
              title: Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: item.detail.isEmpty
                  ? null
                  : Text(item.detail, style: TextStyle(color: t.muted)),
              onTap: () => _showRoutineSheet(context, ref, item: item),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VideoButton(url: item.videoUrl, compact: true),
                  IconButton(
                    tooltip: 'Delete',
                    icon: Icon(Icons.delete_outline, color: t.muted),
                    onPressed: () => dao.deleteRoutineItem(item.id),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextButton.icon(
          style: TextButton.styleFrom(alignment: Alignment.centerLeft),
          onPressed: () => _showRoutineSheet(context, ref),
          icon: const Icon(Icons.add),
          label: Text('Add ${title.toLowerCase()} item'),
        ),
      ],
    );
  }

  Future<void> _showRoutineSheet(
    BuildContext context,
    WidgetRef ref, {
    RoutineItem? item,
  }) async {
    final name = TextEditingController(text: item?.name);
    final detail = TextEditingController(text: item?.detail);
    final video = TextEditingController(text: item?.videoUrl);
    final dao = ref.read(planDaoProvider);
    final title = kind == RoutineKind.warmup
        ? 'Warm-up item'
        : 'Cool-down item';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SheetForm(
        title: item == null
            ? 'Add ${title.toLowerCase()}'
            : 'Edit ${title.toLowerCase()}',
        submitLabel: item == null ? 'Add' : 'Save',
        fields: [
          TextField(
            controller: name,
            autofocus: item == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Name (e.g. Arm circles)',
            ),
          ),
          TextField(
            controller: detail,
            decoration: const InputDecoration(
              labelText: 'Detail (e.g. 30 sec each way, 2 × 15)',
            ),
          ),
          TextField(
            controller: video,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Video link (optional)',
            ),
          ),
        ],
        onSubmit: () async {
          final n = name.text.trim();
          if (n.isEmpty) return false;
          if (item == null) {
            await dao.addRoutineItem(
              dayId: day.id,
              kind: kind,
              name: n,
              detail: detail.text.trim(),
              videoUrl: video.text,
            );
          } else {
            await dao.updateRoutineItem(
              item.id,
              name: n,
              detail: detail.text.trim(),
              videoUrl: video.text,
            );
          }
          return true;
        },
      ),
    );
  }
}

// ---- Body parts / exercises ---------------------------------------------------

class _BodyPartCard extends ConsumerWidget {
  const _BodyPartCard({required this.part});

  final BodyPartPlan part;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final dao = ref.read(planDaoProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    part.name,
                    style: const TextStyle(
                      fontFamily: headingFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'rename') {
                      final name = await promptText(
                        context,
                        title: 'Rename body part',
                        initial: part.name,
                      );
                      if (name != null) await dao.renameBodyPart(part.id, name);
                    } else if (v == 'delete') {
                      final ok =
                          part.exercises.isEmpty ||
                          await confirmDialog(
                            context,
                            title: 'Delete ${part.name}?',
                            message:
                                'Its ${plural(part.exercises.length, 'exercise')} will be deleted too.',
                            confirm: 'Delete',
                            destructive: true,
                          );
                      if (ok) await dao.deleteBodyPart(part.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            if (part.exercises.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'No exercises yet',
                  style: TextStyle(color: t.muted),
                ),
              ),
            for (final e in part.exercises) _ExerciseEditor(exercise: e),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    showAddExerciseSheet(context, ref, part.id, part.name),
                icon: const Icon(Icons.add),
                label: const Text('Add exercise'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseEditor extends ConsumerWidget {
  const _ExerciseEditor({required this.exercise});

  final ExercisePlan exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final dao = ref.read(planDaoProvider);
    final unit = ref.watch(unitProvider);

    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(color: t.line),
          Row(
            children: [
              Expanded(
                child: Text(
                  exercise.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              VideoButton(url: exercise.videoUrl, compact: true),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    await _showEditExerciseSheet(context, ref, exercise);
                  } else if (v == 'delete') {
                    final ok = await confirmDialog(
                      context,
                      title: 'Delete ${exercise.name}?',
                      message: 'Its sets will be deleted. Past workouts stay in History.',
                      confirm: 'Delete',
                      destructive: true,
                    );
                    if (ok) await dao.deleteExercise(exercise.id);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit name / video'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete exercise'),
                  ),
                ],
              ),
            ],
          ),
          for (final (i, s) in exercise.sets.indexed) ...[
            SetRow(
              index: i,
              weightKg: s.weight,
              reps: s.reps,
              unit: unit,
              onWeightChanged: (w) => dao.updateSet(s.id, weightKg: w),
              onRepsChanged: (r) => dao.updateSet(s.id, reps: r),
              onRemove: exercise.sets.length > 1
                  ? () => dao.deleteSet(s.id)
                  : null,
            ),
            const SizedBox(height: 6),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () => dao.addSet(exercise.id),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add set'),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showEditExerciseSheet(
  BuildContext context,
  WidgetRef ref,
  ExercisePlan exercise,
) async {
  final name = TextEditingController(text: exercise.name);
  final video = TextEditingController(text: exercise.videoUrl);
  final dao = ref.read(planDaoProvider);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _SheetForm(
      title: 'Edit exercise',
      submitLabel: 'Save',
      fields: [
        TextField(
          controller: name,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        TextField(
          controller: video,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'Video link (optional)'),
        ),
      ],
      onSubmit: () async {
        final n = name.text.trim();
        if (n.isEmpty) return false;
        await dao.updateExercise(exercise.id, name: n, videoUrl: video.text);
        return true;
      },
    ),
  );
}

/// "Add exercise" form: name, sets (1–12), reps, weight, video.
Future<void> showAddExerciseSheet(
  BuildContext context,
  WidgetRef ref,
  int bodyPartId,
  String bodyPartName,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _AddExerciseForm(bodyPartId: bodyPartId, bodyPartName: bodyPartName),
  );
}

class _AddExerciseForm extends ConsumerStatefulWidget {
  const _AddExerciseForm({
    required this.bodyPartId,
    required this.bodyPartName,
  });

  final int bodyPartId;
  final String bodyPartName;

  @override
  ConsumerState<_AddExerciseForm> createState() => _AddExerciseFormState();
}

class _AddExerciseFormState extends ConsumerState<_AddExerciseForm> {
  final _name = TextEditingController();
  final _weight = TextEditingController();
  final _video = TextEditingController();
  int _sets = 3;
  int _reps = 10;

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final unit = ref.watch(unitProvider);

    Widget counter(
      String label,
      int value,
      int min,
      int max,
      ValueChanged<int> set,
    ) {
      return Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          StepperButton.minus(
            onPressed: value > min ? () => set(value - 1) : null,
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: headingFont,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          StepperButton.plus(
            onPressed: value < max ? () => set(value + 1) : null,
          ),
        ],
      );
    }

    return _SheetForm(
      title: 'Add exercise to ${widget.bodyPartName}',
      submitLabel: 'Add exercise',
      fields: [
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Name (e.g. Bench press)',
          ),
        ),
        counter('Sets', _sets, 1, 12, (v) => setState(() => _sets = v)),
        counter('Reps', _reps, 1, 100, (v) => setState(() => _reps = v)),
        TextField(
          controller: _weight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: InputDecoration(
            labelText: 'Weight',
            suffixText: unit.name,
            helperText: 'Leave empty or 0 for bodyweight',
            helperStyle: TextStyle(color: t.muted),
          ),
        ),
        TextField(
          controller: _video,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'Video link (optional)'),
        ),
      ],
      onSubmit: () async {
        final name = _name.text.trim();
        if (name.isEmpty) return false;
        final w = double.tryParse(_weight.text.replaceAll(',', '.')) ?? 0;
        await ref
            .read(planDaoProvider)
            .addExercise(
              bodyPartId: widget.bodyPartId,
              name: name,
              sets: _sets,
              reps: _reps,
              weightKg: w <= 0 ? 0 : round3(fromDisplay(round1(w), unit)),
              videoUrl: _video.text,
            );
        return true;
      },
    );
  }
}

/// Bottom-sheet form shell: title, fields, submit button. [onSubmit] returns
/// false to keep the sheet open (e.g. a required field is empty).
class _SheetForm extends StatelessWidget {
  const _SheetForm({
    required this.title,
    required this.fields,
    required this.submitLabel,
    required this.onSubmit,
  });

  final String title;
  final List<Widget> fields;
  final String submitLabel;
  final Future<bool> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            for (final f in fields) ...[f, const SizedBox(height: 14)],
            FilledButton(
              onPressed: () async {
                final close = await onSubmit();
                if (close && context.mounted) Navigator.pop(context);
              },
              child: Text(submitLabel),
            ),
          ],
        ),
      ),
    );
  }
}
