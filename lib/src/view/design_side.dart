import 'dart:math';

import 'package:over_react/over_react.dart';
import 'package:built_collection/built_collection.dart';
import 'package:over_react/over_react_redux.dart';
import 'package:scadnano/src/model/selection_box.dart';

import '../model/model.dart';
import '../model/mouseover_data.dart';
import 'design_side_helix.dart';
import '../model/helix.dart';
import '../model/grid.dart';
import '../model/grid_position.dart';
import 'design_side_potential_helix.dart';
import 'design_side_selection_box.dart';

part 'design_side.over_react.g.dart';

// The react/redux stuff keeps going in the background even if we don't render it. To prevent a crash when
// there is an error message to display instead of a DNADesign (since the components for DesignSide and DesignMain
// are rendered manually top-level by vanilla Dart DOM code), we need to say what to do here when model has an error.
UiFactory<_$DesignSideProps> ConnectedDesignSide = connect<Model, _$DesignSideProps>(
  mapStateToProps: (model) => (DesignSide()
    ..helices = model.has_error() ? null : model.dna_design.helices
    ..mouseover_datas = model.has_error() ? null : model.ui_model.mouseover_datas
    ..mouse_svg_pos = model.has_error() ? null : model.ui_model.mouse_svg_pos_side_view
    ..grid = model.has_error() ? null : model.dna_design.grid
    ..selection_box = model.has_error() ? null : model.ui_model.selection_box_side_view),
)(DesignSide);

@Factory()
UiFactory<DesignSideProps> DesignSide = _$DesignSide;

@Props()
class _$DesignSideProps extends UiProps {
  BuiltList<Helix> helices;
  BuiltList<MouseoverData> mouseover_datas;
  Point<num> mouse_svg_pos;
  Grid grid;
  SelectionBox selection_box;
}

@Component2()
class DesignSideComponent extends UiComponent2<DesignSideProps> {
  // FluxUiComponent<DesignSideProps> {
  @override
  Map getDefaultProps() => (newProps());

  @override
  render() {
    if (props.helices == null) {
      // This means there is an error message to display instead of a DNADesign.
      return null;
    }

//    print('rendering side view');
    SelectionBox selection_box = props.selection_box;
    Point<num> mouse_svg_pos = this.props.mouse_svg_pos;
    BuiltList<MouseoverData> mouseover_datas = this.props.mouseover_datas;
    Map<Helix, MouseoverData> helix_to_mouseover_data = {for (var mod in mouseover_datas) mod.helix: mod};
//    List<Helix> helices = this.props.store.helices;
    BuiltList<Helix> helices = this.props.helices;
    //TODO: it's not well-defined what to do when grid=none and there is no grid position for helices
    List helices_components = [
      for (var helix in helices)
//        (DesignSideHelix()
        (ConnectedDesignSideHelix()
          ..helix = helix
          ..grid_position = helix.grid_position
          ..grid = this.props.grid
//          ..mouseover_datas = mouseover_datas
          ..mouseover_data = helix_to_mouseover_data[helix]
          ..key = '${helix.has_grid_position() ? helix.grid_position : helix.svg_position}')()
    ];
    Set<GridPosition> existing_helix_grid_positions = {for (var helix in helices) helix.grid_position};
    return (Dom.g()..className = 'side-view')(
      (DesignSidePotentialHelix()
        ..grid = this.props.grid
        ..existing_helix_grid_positions = existing_helix_grid_positions
        ..mouse_svg_pos = mouse_svg_pos)(),
      (Dom.g()..className = 'helices-side-view')(helices_components),
      (DesignSideSelectionBox()..selection_box = selection_box)(),
    );
  }
}
