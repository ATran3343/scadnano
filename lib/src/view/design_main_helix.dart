import 'dart:html';
import 'dart:math';

import 'package:quiver/iterables.dart' as iter;

import 'package:over_react/over_react.dart';
import 'package:react/react_client.dart';

import '../state/helix.dart';
import '../app.dart';
import '../actions/actions.dart' as actions;
import '../constants.dart' as constants;
import '../util.dart' as util;

part 'design_main_helix.over_react.g.dart';

@Factory()
UiFactory<DesignMainHelixProps> DesignMainHelix = _$DesignMainHelix;

@Props()
class _$DesignMainHelixProps extends UiProps {
  Helix helix;
  int view_order;
  bool strand_create_enabled;
}

@Component2()
class DesignMainHelixComponent extends UiComponent2<DesignMainHelixProps> {
  @override
  bool shouldComponentUpdate(Map nextProps, Map nextState) {
    Helix helix = nextProps['DesignMainHelixProps.helix'];
    bool strand_create_enabled = nextProps['DesignMainHelixProps.strand_create_enabled'];
    return !(helix == props.helix && strand_create_enabled == props.strand_create_enabled);
  }

  @override
  render() {
    Helix helix = props.helix;

    // for helix circles
    var cx = -(2 * constants.BASE_WIDTH_SVG + constants.DISTANCE_BETWEEN_HELICES_SVG / 2);
    var cy = constants.BASE_WIDTH_SVG;

    // for helix horizontal lines
    num width = helix.svg_width();
    num height = helix.svg_height();

    var vert_line_paths = _vert_line_paths(helix);
    int idx = helix.idx;

    var x_start = helix.min_offset * constants.BASE_WIDTH_SVG;
    var x_end = x_start + width;

    Point<num> translation = helix_main_view_translation(helix);

    return (Dom.g()
      ..className = 'helix-main-view'
      ..transform = 'translate(${translation.x} ${translation.y})')([
      (Dom.circle()
        ..className = 'main-view-helix-circle'
        ..cx = '$cx'
        ..cy = '$cy'
        ..r = '${constants.DISTANCE_BETWEEN_HELICES_SVG / 2.0}'
        ..key = 'main-view-helix-circle')(),
      (Dom.text()
        ..className = 'main-view-helix-text'
        ..x = '$cx'
        ..y = '$cy'
        ..key = 'main-view-helix-text')('$idx'),
      (Dom.g()
        ..className = 'helix-lines-group'
        ..key = 'helix-lines-group')(
        (Dom.path()
          ..className = 'helix-lines helix-horz-line'
          ..d = 'M $x_start 0 '
              'H $x_end '
              'M $x_start ${height / 2.0} '
              'H $x_end '
              'M $x_start $height '
              'H $x_end'
          ..key = 'helix-horz-lines')(),
        (Dom.path()
          ..className = 'helix-lines helix-vert-minor-line'
          ..d = vert_line_paths['minor']
          ..key = 'helix-vert-minor-lines')(),
        (Dom.path()
          ..className = 'helix-lines helix-vert-major-line'
          ..d = vert_line_paths['major']
          ..key = 'helix-vert-major-lines')(),
      ),
      if (props.strand_create_enabled)
        (Dom.rect()
          ..onClick = create_strand
          ..x = '0'
          ..y = '0'
          ..width = '$width'
          ..height = '$height'
          ..className = 'helix-invisible-rect'
          ..key = 'helix-invisible-rect')(),
    ]);
  }

  create_strand(SyntheticMouseEvent event_syn) {
    MouseEvent event = event_syn.nativeEvent;
    var offset_forward = util.get_offset_forward(event, props.helix);
    int offset = offset_forward.offset;
    bool forward = offset_forward.forward;
    app.dispatch(actions.StrandCreate(helix_idx: props.helix.idx, offset: offset, forward: forward));
  }
}

//static _default_svg_position(int idx) => Point<num>(0, constants.DISTANCE_BETWEEN_HELICES_SVG * idx);
//
Point<num> helix_main_view_translation(Helix helix) {
  return helix.svg_position;
  //FIXME: standardize this
//  int view_order = helix.view_order;
//  if (helix.position != null) {
//    return Point<num>(
//        helix.position.z * constants.BASE_WIDTH_SVG, helix.position.y * constants.DISTANCE_BETWEEN_HELICES_SVG);
//  } else {
//    return Point<num>(0, constants.DISTANCE_BETWEEN_HELICES_SVG * view_order);
//  }
}

/// Return Map {'minor': thin_lines, 'major': thick_lines} to paths describing minor and major vertical lines.
Map<String, String> _vert_line_paths(Helix helix) {
  List<int> regularly_spaced_ticks(int distance, int start, int end) {
    if (distance == null || distance == 0) {
      return [];
    } else if (distance < 0) {
      throw ArgumentError('distance between major ticks must be positive');
    } else {
      return [for (int offset in iter.range(start, end + 1, distance)) offset];
    }
  }

  var major_tick_distance =
      helix.has_major_tick_distance() ? helix.major_tick_distance : app.state.dna_design.major_tick_distance;
  Set<int> major_ticks = (helix.has_major_ticks()
          ? helix.major_ticks
          : regularly_spaced_ticks(major_tick_distance, helix.min_offset, helix.max_offset))
      .toSet();

  List<String> path_cmds_vert_minor = [];
  List<String> path_cmds_vert_major = [];

  for (int base = helix.min_offset; base <= helix.max_offset; base++) {
    var x = base * constants.BASE_WIDTH_SVG;
    var path_cmds = major_ticks.contains(base) ? path_cmds_vert_major : path_cmds_vert_minor;
    path_cmds.add('M $x 0');
    path_cmds.add('v ${helix.svg_height()}');
    x += constants.BASE_WIDTH_SVG;
  }

  return {'minor': path_cmds_vert_minor.join(' '), 'major': path_cmds_vert_major.join(' ')};
}
