// Excerpt from lib/screens/calendar_screen.dart
// Responsive calendar: LayoutBuilder measures the real available width and
// switches between a side-by-side layout and a stacked one.

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: LayoutBuilder(
      builder: (context, box) {
        final twoColumns = box.maxWidth >= 760;
        final pad = box.maxWidth >= 640 ? 40.0 : 20.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, pad >= 40 ? 40 : 24, pad, 96),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                if (twoColumns)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 480, child: calendar),
                      const SizedBox(width: 40),
                      Expanded(child: agenda),
                    ],
                  )
                else ...[
                  calendar,
                  const SizedBox(height: 28),
                  agenda,
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}
