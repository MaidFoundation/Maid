import 'package:flutter/material.dart';
import 'package:maid/classes/providers/huggingface_selection.dart';
import 'package:maid/ui/desktop/dropdowns/huggingface_model_dropdown.dart';

class HuggingfaceDialog extends StatelessWidget {
  const HuggingfaceDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Select HuggingFace Model',
        textAlign: TextAlign.center
      ),
      content: const HuggingfaceModelDropdown(),
      actions: [
        FilledButton(
          onPressed: () {
            HuggingfaceSelection.of(context).download();
            Navigator.of(context).pop();
          },
          child: const Text(
            "Download"
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            "Close"
          ),
        ),
      ],
      actionsAlignment: MainAxisAlignment.center,
    );
  }
}