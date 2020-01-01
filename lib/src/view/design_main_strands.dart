import 'package:over_react/over_react.dart';
import 'package:built_collection/built_collection.dart';
import 'package:over_react/over_react_redux.dart';
import 'package:scadnano/src/state/edit_mode.dart';
import 'package:scadnano/src/state/helix.dart';
import 'package:scadnano/src/state/select_mode.dart';
import 'package:scadnano/src/state/select_mode_state.dart';
import 'package:scadnano/src/state/selectable.dart';

import '../state/app_state.dart';
import '../state/strand.dart';
import 'design_main_strand.dart';

part 'design_main_strands.over_react.g.dart';

UiFactory<DesignMainStrandsProps> ConnectedDesignMainStrands =
    connect<AppState, DesignMainStrandsProps>(mapStateToProps: (state) {
  return DesignMainStrands()
    ..strands = state.dna_design.strands
    ..helices = state.dna_design.helices
    ..side_selected_helix_idxs = state.ui_state.side_selected_helix_idxs
    ..selectables_store = state.ui_state.selectables_store
    ..select_mode_state = state.ui_state.select_mode_state
    ..edit_modes = state.ui_state.edit_modes
    ..is_origami = state.dna_design.is_origami
    ..drawing_potential_crossover = state.ui_state.drawing_potential_crossover
    ..moving_dna_ends = state.ui_state.moving_dna_ends;
})(DesignMainStrands);

@Factory()
UiFactory<DesignMainStrandsProps> DesignMainStrands = _$DesignMainStrands;

@Props()
class _$DesignMainStrandsProps extends UiProps {
  BuiltList<Strand> strands;
  BuiltList<Helix> helices;
  BuiltSet<int> side_selected_helix_idxs;
  SelectablesStore selectables_store;
  SelectModeState select_mode_state;
  BuiltSet<EditModeChoice> edit_modes;
  bool drawing_potential_crossover;
  bool moving_dna_ends;
  bool is_origami;
}

@Component2()
class DesignMainStrandsComponent extends UiComponent2<DesignMainStrandsProps> {

  bool origami_type_is_selectable(Strand strand) {
    if (!props.is_origami) {
      return true;
    }
    if (strand.is_scaffold) {
      return props.select_mode_state.modes.contains(SelectModeChoice.scaffold);
    } else {
      return props.select_mode_state.modes.contains(SelectModeChoice.staple);
    }
  }

  bool strand_is_selectable(Strand strand) {
    if (! (props.select_mode_state.modes.contains(SelectModeChoice.strand) &&
        props.edit_modes.contains(EditModeChoice.select))) {
      return false;
    }
    return origami_type_is_selectable(strand);
  }

  @override
  render() {

    return (Dom.g()..className = 'strands-main-view')([
      for (var strand in props.strands)
//        (ConnectedDesignMainStrand()
        (DesignMainStrand()
          ..strand = strand
          ..side_selected_helix_idxs = props.side_selected_helix_idxs
          ..selected = props.selectables_store.selected(strand)
          ..selectable = strand_is_selectable(strand)
          ..origami_type_is_selectable = origami_type_is_selectable(strand)
          ..helices = props.helices
          ..selectables_store = props.selectables_store
          ..select_mode_state = props.select_mode_state
          ..edit_modes = props.edit_modes
          ..drawing_potential_crossover = props.drawing_potential_crossover
          ..moving_dna_ends = props.moving_dna_ends
          ..key = strand.toString())()
    ]);
  }
}
