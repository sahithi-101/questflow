import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';

/// A full-width Home bar: a coloured block with the headline number on the
/// left, details on the right. The block colour is the item kind.
class SummaryBar extends StatelessWidget {
  const SummaryBar({
    super.key,
    required this.color,
    required this.icon,
    required this.headline,
    required this.caption,
    required this.title,
    required this.child,
    required this.onTap,
    required this.semanticLabel,
  });

  final Color color;
  final IconData icon;
  final String headline;
  final String caption;
  final String title;
  final Widget child;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 480;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Material(
          color: QfColors.pith,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: narrow ? 92 : 124,
                    color: color,
                    padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(icon, color: QfColors.pith, size: 20),
                        const SizedBox(height: 12),
                        Text(headline,
                            style: QfTheme.display(narrow ? 36 : 44,
                                color: QfColors.pith, height: 1.0, spacing: -1.2)),
                        const SizedBox(height: 2),
                        Text(caption,
                            style: const TextStyle(
                                color: QfColors.pith, fontSize: 13)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(title,
                                    style: Theme.of(context).textTheme.titleMedium),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: QfColors.bistreSoft),
                            ],
                          ),
                          const SizedBox(height: 8),
                          child,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Short fact inside a bar. Pass [onTap] to make it its own link.
class StatPill extends StatelessWidget {
  const StatPill(this.text, {super.key, this.color, this.onTap});

  final String text;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final filled = color != null;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color : Colors.transparent,
        border: filled ? null : Border.all(color: QfColors.rule),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: filled ? FontWeight.w700 : FontWeight.w400,
          color: filled ? QfColors.pith : QfColors.bistre,
        ),
      ),
    );
    if (onTap == null) return pill;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: pill,
    );
  }
}
