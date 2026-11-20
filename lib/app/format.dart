import 'package:intl/intl.dart';

/// Display unit. Weights are always stored in kg.
enum WeightUnit {
  kg,
  lb;

  static WeightUnit fromName(String? name) =>
      name == 'lb' ? WeightUnit.lb : WeightUnit.kg;
}

const kgPerLb = 0.45359237;

double toDisplay(double kg, WeightUnit unit) =>
    unit == WeightUnit.kg ? kg : kg / kgPerLb;

double fromDisplay(double value, WeightUnit unit) =>
    unit == WeightUnit.kg ? value : value * kgPerLb;

/// Rounds to one decimal place (the +/− step).
double round1(double v) => (v * 10).roundToDouble() / 10;

/// Rounds to three decimal places (what we store).
double round3(double v) => (v * 1000).roundToDouble() / 1000;

/// "60", "62.5", "BW" for 0. No unit.
String fmtWeightValue(double kg, WeightUnit unit) {
  if (kg <= 0) return 'BW';
  return fmtNumber(round1(toDisplay(kg, unit)));
}

/// "60 kg", "132.3 lb", "BW".
String fmtWeight(double kg, WeightUnit unit) {
  if (kg <= 0) return 'BW';
  return '${fmtWeightValue(kg, unit)} ${unit.name}';
}

/// "60×8", "BW×12".
String fmtSet(double kg, int reps, WeightUnit unit) =>
    '${fmtWeightValue(kg, unit)}×$reps';

/// Number with up to [decimals] decimals and no trailing zeros.
String fmtNumber(double v, {int decimals = 1}) {
  var s = v.toStringAsFixed(decimals);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return s == '-0' ? '0' : s;
}

/// Volume with thousands separators: "1,320 kg".
String fmtVolume(double kg, WeightUnit unit) =>
    '${NumberFormat.decimalPattern('en_US').format(toDisplay(kg, unit).round())} ${unit.name}';

String plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : (many ?? '${one}s')}';

String fmtDate(DateTime d) => DateFormat('EEE, d MMM').format(d);
String fmtDateLong(DateTime d) => DateFormat('EEE, d MMM yyyy').format(d);
String fmtTime(DateTime d) => DateFormat('h:mm a').format(d);
String fmtFileDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// mm:ss or h:mm:ss.
String fmtElapsed(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// Monday 00:00 of the week containing [d].
DateTime startOfWeek(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}
