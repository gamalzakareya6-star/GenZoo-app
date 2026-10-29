import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/services/url_service.dart';

final RegExp _urlRegex = RegExp(r'(https?://[^\s<>"]+|www\.[^\s<>"]+)', caseSensitive: false);

/// Text whose links open when tapped and which can be selected and copied
/// (long-press to select). A trailing punctuation mark is not part of the link.
class LinkifiedText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const LinkifiedText(this.text, {super.key, this.style});

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  List<InlineSpan> _build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final text = widget.text;
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _urlRegex.allMatches(text)) {
      var link = m.group(0)!;
      // Drop punctuation that usually ends a sentence rather than the link.
      final trimmed = link.replaceFirst(RegExp(r'[.,;:!?)\]}،؛]+$'), '');
      final cut = link.length - trimmed.length;
      link = trimmed;
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));

      final url = link.toLowerCase().startsWith('www.') ? 'https://$link' : link;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => UrlService.launchWebUrl(context, url);
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: link,
        recognizer: recognizer,
        style: const TextStyle(
          color: Color(0xFF2563EB),
          decoration: TextDecoration.underline,
        ),
      ));
      last = m.end - cut;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      TextSpan(style: widget.style, children: _build(context)),
    );
  }
}

/// Small "copy" button for a post's full text.
class CopyTextButton extends StatelessWidget {
  final String text;
  final String label;

  const CopyTextButton({super.key, required this.text, this.label = 'نسخ النص'});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم النسخ')),
          );
        }
      },
      icon: const Icon(Icons.copy_rounded, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
    );
  }
}
