import 'bound_substrand.dart';
import 'select_mode.dart';

/// Implemented by both [Crossover] and [Loopout].
abstract class Linker {
  int get prev_substrand_idx;
  int get next_substrand_idx;

  String get strand_id;

  SelectModeChoice select_mode();

  String id();
}