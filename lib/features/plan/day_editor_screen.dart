import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../data/csv_codec.dart' show formatCsvNumber;
import '../../data/database.dart';
import '../../data/models.dart';
import '../../widgets/async_view.dart';
import '../../widgets/ui.dart';

/// Edit one day: warm-up, body parts → exercises → sets, cool-down.
class DayEditorScreen extends ConsumerStatefulWidget {
  const DayEditorScreen({super.key, required this.dayId});

  final int dayId;

  @override
  ConsumerState<DayEditorScreen> createState() => _DayEditorScreenState();
}

class _DayEditorScreenState extends ConsumerState<DayEditorScreen> {
  /// Body part whose "Add exercise" form is open.
  int? _draftFor;
  final _draftName = TextEditingController();
  final _draftSets = TextEditingController(text: '3');
  final _draftReps = TextEditingController(text: '10');
  final _draftWeight = TextEditingController();
  final _draftVideo = TextEditingController();
  final _partDraft = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _draftName,
      _draftSets,
      _draftReps,
      _draftWeight,
      _draftVideo,
      _partDraft,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _openDraft(int partId) {
    setState(() {
      _draftFor = partId;
      _draftName.clear();
      _draftSets.text = '3';
      _draftReps.text = '10';
      _draftWeight.clear();
      _draftVideo.clear();
    });
  }

  Future<void> _saveDraft(int partId) async {
    final name = _draftName.text.trim();
    if (name.isEmpty) return;
    final unit = ref.read(unitProvider);
    final sets = (int.tryParse(_draftSets.text) ?? 3).clamp(1, 12);
    final reps = int.tryParse(_draftReps.text) ?? 10;
    final w = double.tryParse(_draftWeight.text.replaceAll(',', '.')) ?? 0;
    await ref
        .read(planDaoProvider)
        .addExercise(
          bodyPartId: partId,
          name: name,
          sets: sets,
          reps: reps < 1 ? 10 : reps,
          weightKg: w <= 0 ? 0 : round3(fromDisplay(w, unit)),
          videoUrl: videoHref(_draftVideo.text),
        );
    setState(() => _draftFor = null);
  }

  Future<void> _addPart() async {
    final name = _partDraft.text.trim();
    if (name.isEmpty) return;
    final id = await ref.read(planDaoProvider).addBodyPart(widget.dayId, name);
    _partDraft.clear();
    _openDraft(id);
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(planProvider);
    final t = context.tokens;

    return Scaffold(
      body: SafeArea(
        child: AsyncView(
          value: plan,
          builder: (days) {
            final day = days.where((d) => d.id == widget.dayId).firstOrNull;
            if (day == null) {
              return Center(
                child: Text(
                  'This day no longer exists.',
                  style: inter(15, color: t.muted),
                ),
              );
            }
            final meta = day.parts.isNotEmpty
                ? '${plural(day.parts.length, 'body part')} · '
                      '${plural(day.exerciseCount, 'exercise')} · '
                      '${plural(day.setCount, 'set')}'
                : 'Add your first body part below';

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                BackHeader(
                  title: day.name,
                  subtitle: meta,
                  backLabel: 'Back to workouts',
                  onBack: () => context.pop(),
                ),
                const SizedBox(height: 16),
                _RoutineCard(day: day, kind: RoutineKind.warmup),
                if (day.parts.isEmpty) ...[
                  const SizedBox(height: 16),
                  CardBox(
                    dashed: true,
                    color: Colors.transparent,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'No body parts yet',
                          style: grotesk(17, color: t.ink),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Add one below (for example Chest), then add exercises and '
                          'sets to it. You need at least one exercise to start this day.',
                          textAlign: TextAlign.center,
                          style: inter(13, color: t.muted),
                        ),
                      ],
                    ),
                  ),
                ],
                for (final part in day.parts) ...[
                  const SizedBox(height: 16),
                  _partCard(context, part),
                ],
                const SizedBox(height: 16),
                _addPartCard(context),
                const SizedBox(height: 16),
                _RoutineCard(day: day, kind: RoutineKind.cooldown),
                if (day.canStart) ...[
                  const SizedBox(height: 16),
                  Btn(
                    onTap: () async {
                      await ref.read(workoutDaoProvider).start(day);
                      if (context.mounted) {
                        context.pushReplacement(Routes.workout);
                      }
                    },
                    height: 52,
                    color: t.accent,
                    child: BtnLabel(
                      'Start ${day.name}',
                      style: inter(15, weight: FontWeight.w700, color: t.ink),
                      leading: SvgIcon(Ico.playFilled, size: 14, color: t.ink),
                      gap: 8,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _addPartCard(BuildContext context) {
    final t = context.tokens;
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add a body part',
            style: inter(12, weight: FontWeight.w600, color: t.muted),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _partDraft,
            textCapitalization: TextCapitalization.words,
            style: inter(15, weight: FontWeight.w500, color: t.ink),
            decoration: fieldDecoration(t, hint: 'e.g. Shoulders, Legs, Abs'),
            onSubmitted: (_) => _addPart(),
          ),
          const SizedBox(height: 10),
          Btn(
            onTap: _addPart,
            height: 44,
            radius: 12,
            color: t.dark,
            child: BtnLabel(
              'Add body part',
              style: inter(14, weight: FontWeight.w600, color: Fixed.white),
              leading: const SvgIcon(Ico.plus, size: 16, color: Fixed.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _partCard(BuildContext context, BodyPartPlan part) {
    final t = context.tokens;
    final dao = ref.read(planDaoProvider);
    final unit = ref.watch(unitProvider);
    final drafting = _draftFor == part.id;

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: part.name,
                        style: grotesk(
                          19,
                          weight: FontWeight.w600,
                          color: t.ink,
                        ),
                      ),
                      TextSpan(
                        text: '  ${plural(part.exercises.length, 'exercise')}',
                        style: inter(13, color: t.muted),
                      ),
                    ],
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(10, 0),
                child: IconBtn(
                  icon: Ico.trash,
                  label: 'Remove ${part.name}',
                  color: t.muted,
                  stroke: 2,
                  onTap: () async {
                    final ok =
                        part.exercises.isEmpty ||
                        await confirmDialog(
                          context,
                          title: 'Remove ${part.name}?',
                          message:
                              'Its ${plural(part.exercises.length, 'exercise')} '
                              'will be deleted too.',
                          confirm: 'Remove',
                        );
                    if (ok) await dao.deleteBodyPart(part.id);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final e in part.exercises) _exerciseBlock(context, e, unit),
          const SizedBox(height: 6),
          if (drafting)
            _draftForm(context, part, unit)
          else
            Btn(
              onTap: () => _openDraft(part.id),
              height: 44,
              radius: 12,
              dashed: true,
              border: BorderSide(color: t.border2, width: 1.5),
              child: BtnLabel(
                'Add exercise to ${part.name}',
                style: inter(14, weight: FontWeight.w600, color: t.ink),
                leading: SvgIcon(Ico.plus, size: 16, color: t.ink),
              ),
            ),
        ],
      ),
    );
  }

  Widget _exerciseBlock(BuildContext context, ExercisePlan e, WeightUnit unit) {
    final t = context.tokens;
    final dao = ref.read(planDaoProvider);
    final pairs = e.sets.map((s) => fmtSet(s.weight, s.reps, unit)).join(' · ');
    const cols = <double?>[36, null, null, 36];

    Widget grid(List<Widget> children) => Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          if (cols[i] == null)
            Expanded(child: children[i])
          else
            SizedBox(width: cols[i], child: children[i]),
        ],
      ],
    );

    final header = inter(
      11,
      weight: FontWeight.w700,
      letterSpacing: 0.06,
      color: t.muted,
    );

    return Container(
      key: ValueKey('ex-${e.id}'),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.name,
                      style: inter(15, weight: FontWeight.w600, color: t.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${plural(e.sets.length, 'set')}'
                      '${pairs.isEmpty ? '' : ' · $pairs'}',
                      style: inter(12, color: t.muted),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(10, 0),
                child: IconBtn(
                  icon: Ico.trash,
                  label: 'Remove ${e.name}',
                  color: t.muted,
                  iconSize: 16,
                  onTap: () => dao.deleteExercise(e.id),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          grid([
            Text('SET', style: header),
            Text('WEIGHT (${unit.name.toUpperCase()})', style: header),
            Text('REPS', style: header),
            const SizedBox(),
          ]),
          for (final (i, s) in e.sets.indexed) ...[
            const SizedBox(height: 8),
            KeyedSubtree(
              key: ValueKey('set-${s.id}'),
              child: grid([
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.ground,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: inter(13, weight: FontWeight.w700, color: t.ink),
                  ),
                ),
                SyncedField(
                  value: formatCsvNumber(round3(toDisplay(s.weight, unit))),
                  number: true,
                  decimal: true,
                  fontSize: 15,
                  weight: FontWeight.w600,
                  semanticLabel: '${e.name} set ${i + 1} weight',
                  onChanged: (v) {
                    final w = double.tryParse(v.replaceAll(',', '.'));
                    if (w != null) {
                      dao.updateSet(
                        s.id,
                        weightKg: round3(fromDisplay(w, unit)),
                      );
                    }
                  },
                ),
                SyncedField(
                  value: '${s.reps}',
                  number: true,
                  fontSize: 15,
                  weight: FontWeight.w600,
                  semanticLabel: '${e.name} set ${i + 1} reps',
                  onChanged: (v) {
                    final r = int.tryParse(v);
                    if (r != null) dao.updateSet(s.id, reps: r);
                  },
                ),
                IconBtn(
                  icon: Ico.trash,
                  label: 'Remove set ${i + 1}',
                  color: t.muted,
                  iconSize: 14,
                  width: 36,
                  onTap: () => dao.deleteSet(s.id),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Btn(
              onTap: () => dao.addSet(e.id),
              height: 40,
              radius: 10,
              color: t.ground,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: BtnLabel(
                'Add set',
                style: inter(13, weight: FontWeight.w600, color: t.ink),
                leading: SvgIcon(Ico.plus, size: 14, color: t.ink, stroke: 2.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          VideoLinkRow(
            value: e.videoUrl ?? '',
            name: e.name,
            onChanged: (v) => dao.updateExercise(e.id, videoUrl: v),
          ),
        ],
      ),
    );
  }

  Widget _draftForm(BuildContext context, BodyPartPlan part, WeightUnit unit) {
    final t = context.tokens;
    final label = inter(12, weight: FontWeight.w600, color: t.muted);

    Widget field(
      String text,
      TextEditingController c, {
      String? hint,
      bool number = false,
      bool decimal = false,
      bool url = false,
      bool autofocus = false,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(text, style: label),
        const SizedBox(height: 4),
        TextField(
          controller: c,
          autofocus: autofocus,
          keyboardType: number
              ? TextInputType.numberWithOptions(decimal: decimal)
              : (url ? TextInputType.url : TextInputType.text),
          textCapitalization: number || url
              ? TextCapitalization.none
              : TextCapitalization.sentences,
          inputFormatters: number
              ? [
                  FilteringTextInputFormatter.allow(
                    decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
                  ),
                ]
              : null,
          style: inter(15, weight: FontWeight.w500, color: t.ink),
          decoration: fieldDecoration(t, hint: hint),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.ground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field(
            'Exercise name',
            _draftName,
            hint: 'e.g. Bench press',
            autofocus: true,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: field('Sets', _draftSets, number: true)),
              const SizedBox(width: 8),
              Expanded(child: field('Reps', _draftReps, number: true)),
              const SizedBox(width: 8),
              Expanded(
                child: field(
                  'Weight (${unit.name})',
                  _draftWeight,
                  hint: '0',
                  number: true,
                  decimal: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Starting values for every set. You can change each set after adding.',
            style: inter(12, color: t.muted),
          ),
          const SizedBox(height: 10),
          field(
            'Video link (optional)',
            _draftVideo,
            hint: 'YouTube or any video URL',
            url: true,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Btn(
                  onTap: () => setState(() => _draftFor = null),
                  height: 44,
                  radius: 12,
                  color: Fixed.white,
                  border: BorderSide(color: t.border),
                  child: Text(
                    'Cancel',
                    style: inter(14, weight: FontWeight.w600, color: t.ink),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Btn(
                  onTap: () => _saveDraft(part.id),
                  height: 44,
                  radius: 12,
                  color: t.dark,
                  child: Text(
                    'Add exercise',
                    style: inter(
                      14,
                      weight: FontWeight.w600,
                      color: Fixed.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Warm-up / cool-down card: icon tile, items (name · video link), add.
class _RoutineCard extends ConsumerWidget {
  const _RoutineCard({required this.day, required this.kind});

  final DayPlan day;
  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final dao = ref.read(planDaoProvider);
    final warm = kind == RoutineKind.warmup;
    final items = warm ? day.warmups : day.cooldowns;
    final title = warm ? 'Warm-up' : 'Cool-down';
    final countLabel = items.isNotEmpty
        ? '${plural(items.length, 'item')} · '
              '${warm ? 'before you lift' : 'after your last set'}'
        : (warm
              ? 'Optional · shows first in your workout'
              : 'Optional · shows last in your workout');

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.ink,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SvgIcon(
                    warm ? Ico.flame : Ico.snow,
                    size: 16,
                    color: t.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: grotesk(
                          19,
                          weight: FontWeight.w600,
                          color: t.ink,
                        ),
                      ),
                      Text(countLabel, style: inter(12, color: t.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final item in items)
            Container(
              key: ValueKey(item.id),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: t.divider)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SyncedField(
                          value: item.name,
                          hint: 'Exercise name',
                          semanticLabel: '$title exercise name',
                          onChanged: (v) =>
                              dao.updateRoutineItem(item.id, name: v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconBtn(
                        icon: Ico.trash,
                        label: 'Remove ${item.name}',
                        color: t.muted,
                        iconSize: 14,
                        onTap: () => dao.deleteRoutineItem(item.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  VideoLinkRow(
                    value: item.videoUrl ?? '',
                    name: item.name,
                    onChanged: (v) =>
                        dao.updateRoutineItem(item.id, videoUrl: v),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Btn(
            onTap: () =>
                dao.addRoutineItem(dayId: day.id, kind: kind, name: ''),
            height: 44,
            radius: 12,
            dashed: true,
            border: BorderSide(color: t.border2, width: 1.5),
            child: BtnLabel(
              'Add ${title.toLowerCase()} exercise',
              style: inter(14, weight: FontWeight.w600, color: t.ink),
              leading: SvgIcon(Ico.plus, size: 16, color: t.ink),
            ),
          ),
        ],
      ),
    );
  }
}
