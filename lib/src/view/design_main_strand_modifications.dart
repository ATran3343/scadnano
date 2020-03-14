import 'package:built_collection/built_collection.dart';
import 'package:over_react/over_react.dart';
import 'package:scadnano/src/state/bound_substrand.dart';
import 'package:scadnano/src/state/dna_design.dart';
import 'package:scadnano/src/state/loopout.dart';
import 'package:scadnano/src/state/substrand.dart';
import 'package:scadnano/src/view/design_main_strand_modification_bound_substrand.dart';

import '../state/strand.dart';
import '../state/helix.dart';

part 'design_main_strand_modifications.over_react.g.dart';

@Factory()
UiFactory<DesignMainStrandModificationsProps> DesignMainStrandModifications = _$DesignMainStrandModifications;

@Props()
class _$DesignMainStrandModificationsProps extends UiProps {
  Strand strand;
  BuiltMap<int, Helix> helices;
}

@Component2()
class DesignMainStrandModificationsComponent extends UiComponent2<DesignMainStrandModificationsProps> {
  @override
  render() {
    List<ReactElement> modifications = [];

    if (props.strand.modification_5p != null) {
      var ss = props.strand.first_bound_substrand();
      Helix helix_5p = props.helices[ss.helix];
      modifications.add((DesignMainStrandModificationBoundSubstrand()
        ..address = Address(helix_idx: helix_5p.idx, offset: ss.offset_5p, forward: ss.forward)
        ..helix = helix_5p
        ..modification = props.strand.modification_5p
        ..key = "5'")());
    }

    if (props.strand.modification_3p != null) {
      var ss = props.strand.last_bound_substrand();
      Helix helix_3p = props.helices[ss.helix];
      modifications.add((DesignMainStrandModificationBoundSubstrand()
        ..address = Address(helix_idx: helix_3p.idx, offset: ss.offset_3p, forward: ss.forward)
        ..helix = helix_3p
        ..modification = props.strand.modification_3p
        ..key = "3'")());
    }

    for (var dna_idx_mod in props.strand.modifications_int.keys) {
      // find substrand with modification, and the DNA index of its 5' end
      Substrand ss_with_mod;
      int dna_index_5p_end_of_ss_with_mod = 0;
      for (var ss in props.strand.substrands) {
        int ss_dna_length = ss.dna_length();
        if (dna_index_5p_end_of_ss_with_mod + ss_dna_length > dna_idx_mod) {
          ss_with_mod = ss;
          break;
        }
        dna_index_5p_end_of_ss_with_mod += ss_dna_length;
      }

      if (ss_with_mod is BoundSubstrand) {
        int ss_dna_idx = dna_idx_mod - dna_index_5p_end_of_ss_with_mod;
        int offset = ss_with_mod.substrand_dna_idx_to_substrand_offset(ss_dna_idx, ss_with_mod.forward);
        Helix helix = props.helices[ss_with_mod.helix];
        modifications.add((DesignMainStrandModificationBoundSubstrand()
          ..address = Address(
              helix_idx: helix.idx,
              offset: offset,
              forward: ss_with_mod.forward)
          ..helix = helix
          ..modification = props.strand.modifications_int[dna_idx_mod]
          ..key = "internal-${dna_idx_mod}")());
      } else if (ss_with_mod is Loopout) {
        throw IllegalDNADesignError('currently unsupported to draw modification on Loopout');
      }
    }

    return modifications.isEmpty ? null : (Dom.g()..className = 'modifications')(modifications);
  }
}
