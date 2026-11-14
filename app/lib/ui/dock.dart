import 'package:material_ui/material_ui.dart';

/// One tab in the [FloatingDock].
class DockItem {
  const DockItem({required this.icon, required this.selectedIcon, required this.label});
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Sidekick 4.0's phone tab bar (design/emulator `.dock`): a rounded bar
/// floating above the bottom edge; the selected tab is a white pill with its
/// icon and name, the others just icons. Switching springs the pill open.
/// No badges or dots on it (the owner's call).
class FloatingDock extends StatelessWidget {
  const FloatingDock({super.key, required this.items, required this.index, required this.onTap});

  final List<DockItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: const Color(0x1FFFFFFF)),
          boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 30, offset: Offset(0, 10))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          // Spread across the bar; on a narrow phone with big text, the
          // whole row shrinks a little instead of running off the edge.
          child: LayoutBuilder(
            builder: (context, box) => FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: box.maxWidth),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      _DockButton(item: items[i], selected: i == index, onTap: () => onTap(i)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatefulWidget {
  const _DockButton({required this.item, required this.selected, required this.onTap});
  final DockItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DockButton> createState() => _DockButtonState();
}

class _DockButtonState extends State<_DockButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final open = reduce ? Duration.zero : const Duration(milliseconds: 420);
    // A soft overshoot, like the website's springy buttons.
    const spring = Cubic(0.34, 1.4, 0.64, 1);
    final fg = widget.selected ? scheme.onSecondaryContainer : scheme.onSurface;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.92 : 1,
          duration: reduce ? Duration.zero : const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: open,
            curve: spring,
            height: 48,
            constraints: const BoxConstraints(minWidth: 46),
            padding: EdgeInsets.symmetric(horizontal: widget.selected ? 18 : 11),
            decoration: BoxDecoration(
              color: widget.selected ? scheme.secondaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.selected ? widget.item.selectedIcon : widget.item.icon, size: 22, color: fg),
                AnimatedSize(
                  duration: open,
                  curve: spring,
                  child: widget.selected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 9),
                          child: Text(
                            widget.item.label,
                            maxLines: 1,
                            style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
