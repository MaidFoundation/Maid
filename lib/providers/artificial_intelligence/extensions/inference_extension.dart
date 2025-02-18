part of 'package:maid/main.dart';

extension InferenceExtension on ArtificialIntelligence {
  void prompt(String message) async {
    root.chain.last.addChild(UserChatMessage(message));

    busy = true;
    notify();

    Stream<String> stream;
    switch (ecosystem) {
      case LlmEcosystem.llamaCPP:
        stream = llamaPrompt(root.chainData.copy());
        break;
      case LlmEcosystem.ollama:
        stream = ollamaPrompt(root.chainData.copy());
        break;
    }

    root.chain.last.addChild(AssistantChatMessage(''));
    notify();

    await for (final response in stream) {
      root.chain.last.data.content += response;
      notify();
    }

    busy = false;
    saveAndNotify();
  }

  void regenerate(GeneralTreeNode<ChatMessage> node) async {
    busy = true;
    notify();

    if (_ecosystem == LlmEcosystem.llamaCPP) {
      reloadModel();
      assert(_llama != null);
    }

    node.addChild(AssistantChatMessage(''));
    notify();

    assert(root.chainData.last is AssistantChatMessage);

    final chainData = root.chainData.copy();
    chainData.removeLast();

    Stream<String> stream;
    switch (ecosystem) {
      case LlmEcosystem.llamaCPP:
        stream = llamaPrompt(chainData);
        break;
      case LlmEcosystem.ollama:
        stream = ollamaPrompt(chainData);
        break;
    }

    assert(node.currentChild == root.chain.last);

    await for (final response in stream) {
      root.chain.last.data.content += response;
      notify();
    }

    busy = false;
    saveAndNotify();
  }

  void stop() async {
    switch (ecosystem) {
      case LlmEcosystem.llamaCPP:
        _llama?.stop();
        break;
      case LlmEcosystem.ollama:
        _ollamaClient.endSession();
        break;
    }


    busy = false;
    saveAndNotify();
  }
}