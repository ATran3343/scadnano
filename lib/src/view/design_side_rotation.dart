import 'package:over_react/over_react.dart';
import 'package:scadnano/src/model/mouseover_data.dart';
import 'package:scadnano/src/model/strand.dart';

import '../model/helix.dart';
import 'design_side_rotation_arrow.dart';

part 'design_side_rotation.over_react.g.dart';

@Factory()
UiFactory<DesignSideRotationProps> DesignSideRotation = _$DesignSideRotation;

@Props()
class _$DesignSideRotationProps extends UiProps {
  double radius;
  Helix helix;
  int offset;
}

@Component()
class DesignSideRotationComponent extends UiComponent<DesignSideRotationProps> {
  @override
  Map getDefaultProps() => (newProps());

  @override
  render() {
    Helix helix = this.props.helix;
    int offset = this.props.offset;
    num radius = this.props.radius;

    Strand strand_forward;
    Strand strand_reverse;

    var substrands = helix.substrands_at(offset);
    for (var ss in substrands) {
      if (ss.forward) {
        strand_forward = ss.strand;
      } else {
        strand_reverse = ss.strand;
      }
    }

    var rotation_3p = helix.rotation_3p(offset);
    var rotation_5p = helix.rotation_5p(offset);
    var color_3p = strand_forward == null ? 'black' : strand_forward.color.toHexColor().toCssString();
    var color_5p = strand_reverse == null ? 'black' : strand_reverse.color.toHexColor().toCssString();

    return Dom.g()(
      (DesignSideRotationArrow()
        ..radius = radius
        ..angle = rotation_3p
        ..color = color_3p
        ..className = 'rotation-arrow')(),
      (DesignSideRotationArrow()
        ..radius = radius
        ..angle = rotation_5p
        ..color = color_5p
        ..className = 'rotation-arrow')(),
    );
  }
}
