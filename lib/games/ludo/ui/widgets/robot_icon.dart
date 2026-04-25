import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class RobotIcon extends StatelessWidget {
  final double size;
  final Color color;

  const RobotIcon({super.key, this.size = 24, this.color = Colors.black});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      "assets/icons/robot_2.svg",
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
