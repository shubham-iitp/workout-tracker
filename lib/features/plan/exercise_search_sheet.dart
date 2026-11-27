import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../app/format.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../widgets/ui.dart';

/// One exercise the user already has somewhere in the plan.
class CatalogEntry {
  CatalogEntry({required this.exercise, required this.part, required this.day});

  final ExercisePlan exercise;
  final String part;
  final String day;

  String get name => exercise.name;
}

/// Every exercise in the plan, across all days, one entry per name
/// (case-insensitive; when a name appears twice the first found wins).
List<CatalogEntry> buildExerciseCatalog(List<DayPlan> days) {
  final out = <CatalogEntry>[];
  final seen = <String>{};
  for (final d in days) {
    for (final p in d.parts) {
      for (final e in p.exercises) {
        if (!seen.add(_key(e.name))) continue;
        out.add(CatalogEntry(exercise: e, part: p.name, day: d.name));
      }
    }
  }
  return out;
}

/// Body-part filter ([filter] null = All) combined with a case-insensitive
/// match of [query] against the exercise name or its body part.
List<CatalogEntry> filterCatalog(
  List<CatalogEntry> all, {
  String query = '',
  String? filter,
}) {
  final q = query.trim().toLowerCase();
  return [
    for (final x in all)
      if ((filter == null || x.part == filter) &&
          (q.isEmpty ||
              x.name.toLowerCase().contains(q) ||
              x.part.toLowerCase().contains(q)))
        x,
  ];
}

String _key(String name) => name.trim().toLowerCase();

/// What the user chose in the search sheet.
sealed class ExerciseSearchResult {}

/// Copy this exercise into the target body part.
class SearchPicked extends ExerciseSearchResult {
  SearchPicked(this.entry);
  final CatalogEntry entry;
}

/// Nothing matched: put [name] in the "Exercise name" field.
class SearchAsNew extends ExerciseSearchResult {
  SearchAsNew(this.name);
  final String name;
}

/// Opens "Your exercises · Adding to [target]".
Future<ExerciseSearchResult?> showExerciseSearch(
  BuildContext context, {
  required List<DayPlan> days,
  required BodyPartPlan target,
  required WeightUnit unit,
}) {
  final t = context.tokens;
  return showModalBottomSheet<ExerciseSearchResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: t.ground,
    barrierColor: Fixed.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ExerciseSearchSheet(
      catalog: buildExerciseCatalog(days),
      target: target,
      unit: unit,
    ),
  );
}

class _ExerciseSearchSheet extends StatefulWidget {
  const _ExerciseSearchSheet({
    required this.catalog,
    required this.target,
    required this.unit,
  });

  final List<CatalogEntry> catalog;
  final BodyPartPlan target;
  final WeightUnit unit;

  @override
  State<_ExerciseSearchSheet> createState() => _ExerciseSearchSheetState();
}

class _ExerciseSearchSheetState extends State<_ExerciseSearchSheet> {
  final _query = TextEditingController();
  String? _filter;
  CatalogEntry? _picked;

  late final Set<String> _here = {
    for (final e in widget.target.exercises) _key(e.name),
  };
  late final List<String> _parts = {for (final x in widget.catalog) x.part}
      .toList();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final height = math.min(780.0, mq.size.height);
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, mq.viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: context.tokens.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _picked == null
                  ? _list(context)
                  : _detail(context, _picked!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final t = context.tokens;
    final q = _query.text.trim();
    final results = filterCatalog(widget.catalog, query: q, filter: _filter);
    final count =
        plural(results.length, 'exercise') +
        (_filter != null ? ' in $_filter' : '') +
        (q.isNotEmpty ? ' matching “$q”' : '');

    Widget chip(String label, String? value) {
      final on = _filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Semantics(
          selected: on,
          child: Btn(
            onTap: () => setState(() => _filter = value),
            height: 36,
            radius: 999,
            color: on ? t.ink : Fixed.white,
            border: BorderSide(color: on ? t.ink : t.border),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: inter(
                13,
                weight: FontWeight.w600,
                color: on ? Fixed.white : t.ink,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your exercises',
                    style: grotesk(22, weight: FontWeight.w700, color: t.ink),
                  ),
                  Text(
                    'Adding to ${widget.target.name}',
                    style: inter(13, color: t.muted),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(10, 0),
              child: IconBtn(
                icon: Ico.close,
                label: 'Close search',
                color: t.ink,
                onTap: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _query,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.sentences,
          style: inter(15, weight: FontWeight.w500, color: t.ink),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search exercise or body part',
            hintStyle: inter(
              15,
              weight: FontWeight.w500,
              color: t.muted.withValues(alpha: 0.7),
            ),
            filled: true,
            fillColor: Fixed.white,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: SvgIcon(Ico.search, size: 18, color: t.muted),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 38,
              minHeight: 18,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.ink, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.ink, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.ink, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          label: 'Filter by body part',
          container: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [chip('All', null), for (final p in _parts) chip(p, p)],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          count.toUpperCase(),
          style: inter(
            12,
            weight: FontWeight.w700,
            letterSpacing: 0.08,
            color: t.muted,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: results.isEmpty
              ? ListView(
                  padding: const EdgeInsets.only(bottom: 20),
                  children: [_noMatch(context, q)],
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _row(context, results[i]),
                ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, CatalogEntry x) {
    final t = context.tokens;
    final already = _here.contains(_key(x.name));
    final sets = x.exercise.sets;
    final setsLine = sets
        .map((s) => fmtSet(s.weight, s.reps, widget.unit))
        .join(' · ');
    return Opacity(
      opacity: already ? 0.55 : 1,
      child: Btn(
        onTap: already ? null : () => setState(() => _picked = x),
        semanticLabel: already
            ? '${x.name}, already in ${widget.target.name}'
            : 'View ${x.name}',
        color: Fixed.white,
        border: BorderSide(color: t.line),
        radius: 14,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          x.name,
                          style: inter(
                            15,
                            weight: FontWeight.w600,
                            color: t.ink,
                          ),
                        ),
                      ),
                      if ((x.exercise.videoUrl ?? '').isNotEmpty) ...[
                        const SizedBox(width: 6),
                        SvgIcon(Ico.video, size: 14, color: t.muted, stroke: 2),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${x.part} · ${x.day} · ${plural(sets.length, 'set')}',
                    style: inter(12, color: t.muted),
                  ),
                  if (setsLine.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(setsLine, style: inter(12, color: t.ink)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (already)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.line,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Already here',
                  style: inter(11, weight: FontWeight.w700, color: t.ink),
                ),
              )
            else
              SvgIcon(Ico.chevronRight, size: 18, color: t.ink),
          ],
        ),
      ),
    );
  }

  Widget _noMatch(BuildContext context, String q) {
    final t = context.tokens;
    return CardBox(
      dashed: true,
      color: Colors.transparent,
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Column(
        children: [
          Text(
            q.isEmpty ? 'No exercises yet' : 'No match for “$q”',
            textAlign: TextAlign.center,
            style: grotesk(17, weight: FontWeight.w700, color: t.ink),
          ),
          const SizedBox(height: 8),
          Text(
            q.isEmpty
                ? 'Exercises you add to any day show up here.'
                : 'Try another name or body part, or add it as a new exercise.',
            textAlign: TextAlign.center,
            style: inter(13, color: t.muted),
          ),
          if (q.isNotEmpty) ...[
            const SizedBox(height: 12),
            Btn(
              onTap: () => Navigator.pop(context, SearchAsNew(q)),
              height: 44,
              radius: 12,
              color: t.dark,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Add “$q” as new',
                style: inter(14, weight: FontWeight.w600, color: Fixed.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detail(BuildContext context, CatalogEntry x) {
    final t = context.tokens;
    final sets = x.exercise.sets;
    final video = x.exercise.videoUrl ?? '';
    final head = inter(
      11,
      weight: FontWeight.w700,
      letterSpacing: 0.06,
      color: t.muted,
    );
    final num = grotesk(15, weight: FontWeight.w700, color: t.ink);

    Widget grid(Widget a, Widget b, Widget c) => Row(
      children: [
        SizedBox(width: 48, child: a),
        const SizedBox(width: 8),
        Expanded(child: b),
        const SizedBox(width: 8),
        Expanded(child: c),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Transform.translate(
              offset: const Offset(-10, 0),
              child: IconBtn(
                icon: Ico.back,
                label: 'Back to results',
                color: t.ink,
                onTap: () => setState(() => _picked = null),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    x.name,
                    style: grotesk(22, weight: FontWeight.w700, color: t.ink),
                  ),
                  Text(
                    'From ${x.day} · ${x.part}',
                    style: inter(13, color: t.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              CardBox(
                radius: 16,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'WHAT GETS COPIED',
                      style: inter(
                        12,
                        weight: FontWeight.w700,
                        letterSpacing: 0.08,
                        color: t.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    grid(
                      Text('SET', style: head),
                      Text(
                        'WEIGHT (${widget.unit.name.toUpperCase()})',
                        style: head,
                      ),
                      Text('REPS', style: head),
                    ),
                    for (var i = 0; i < sets.length; i++)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: t.divider)),
                        ),
                        child: grid(
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: t.ground,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${i + 1}',
                                style: inter(
                                  13,
                                  weight: FontWeight.w700,
                                  color: t.ink,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            fmtWeightValue(sets[i].weight, widget.unit),
                            style: num,
                          ),
                          Text('${sets[i].reps}', style: num),
                        ),
                      ),
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: t.divider)),
                      ),
                      child: Row(
                        children: [
                          SvgIcon(
                            Ico.video,
                            size: 14,
                            stroke: 2,
                            color: video.isEmpty ? t.muted : t.ink,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              video.isEmpty
                                  ? 'No video link'
                                  : video.replaceFirst(
                                      RegExp(r'^https?://'),
                                      '',
                                    ),
                              style: inter(
                                13,
                                color: video.isEmpty ? t.muted : t.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The copy is a new exercise in ${widget.target.name}. Its '
                'last-time numbers come along, so progress tracking keeps '
                'working. Editing one copy never changes the other.',
                style: inter(13, color: t.muted),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
          child: Btn(
            onTap: () => Navigator.pop(context, SearchPicked(x)),
            height: 52,
            color: t.accent,
            child: Text(
              'Add to ${widget.target.name} · ${plural(sets.length, 'set')}',
              style: inter(15, weight: FontWeight.w700, color: t.ink),
            ),
          ),
        ),
      ],
    );
  }
}
