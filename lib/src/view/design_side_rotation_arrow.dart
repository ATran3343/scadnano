import 'dart:math';

import 'package:over_react/over_react.dart';

part 'design_side_rotation_arrow.over_react.g.dart';

@Factory()
UiFactory<DesignSideRotationArrowProps> DesignSideRotationArrow = _$DesignSideRotationArrow;

@Props()
class _$DesignSideRotationArrowProps extends UiProps {
  double angle;
  double radius;
  String color;
}

@Component()
class DesignSideRotationArrowComponent extends UiComponent<DesignSideRotationArrowProps> {
  @override
  Map getDefaultProps() => (newProps());

  @override
  render() {
    num mag = this.props.radius * 0.93;
    var path_description = 'M 0 0 '
        'h $mag '
        'm ${-mag / 4.0} ${-mag / 6.0} '
        'L ${mag} 0 '
        'm ${-mag / 4.0} ${mag / 6.0} '
        'L ${mag} 0 ';
    num angle_degrees = this.props.angle * 360.0 / (2 * pi);

    return (Dom.path()
      ..transform = 'rotate($angle_degrees)'
      ..d = path_description
      ..fill = "none"
      ..stroke = this.props.color
      ..className = 'rotation-line')();
  }
}
