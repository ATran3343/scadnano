import 'select_mode.dart';

/// Implemented by both [Crossover] and [Loopout].
abstract class Linker {
  int get prev_domain_idx;

  int get next_domain_idx;

  String get strand_id;

  SelectModeChoice select_mode();

  String id();
}
