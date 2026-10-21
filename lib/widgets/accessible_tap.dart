import 'package:flutter/material.dart';

const double kMinTapSize = 48;

class AccessibleTap extends StatelessWidget {
  const AccessibleTap({
    super.key,
    required this.onTap,
    required this.label,
    required this.child,
    this.selected,
  });

  final VoidCallback onTap;

  final String label;
  final Widget child;

  final bool? selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kMinTapSize,
            minWidth: kMinTapSize,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
