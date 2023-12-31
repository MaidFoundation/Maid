import 'dart:async';
import 'dart:isolate';

import 'package:maid/models/isolate_message.dart';
import 'package:maid/models/library_link.dart';
import 'package:maid/models/generation_options.dart';

class LocalGeneration {
  static SendPort? _sendPort;

  static void _libraryIsolate(SendPort initialSendPort) async {
    _sendPort = initialSendPort;
    final receivePort = ReceivePort();
    _sendPort!.send(receivePort.sendPort);

    late LibraryLink link;
    Completer completer = Completer();
    receivePort.listen((data) {
      if (data is IsolateMessage) {
        switch (data.code) {
          case IsolateCode.start:
            link = LibraryLink(data.options!);
            break;
          case IsolateCode.stop:
            link.stop();
            break;
          case IsolateCode.prompt:
            link.prompt(data.stream!, data.input!);
            break;
          case IsolateCode.dispose:
            link.dispose();
            completer.complete();
            break;
        }
      }
    });
    await completer.future;
  }

  static Future<void> prompt(String input, GenerationOptions options,
      StreamController<String> stream) async {
    if (_sendPort == null) {
      final receivePort = ReceivePort();
      await Isolate.spawn(_libraryIsolate, receivePort.sendPort);
      _sendPort = await receivePort.first as SendPort;

      _sendPort!.send(IsolateMessage(
        IsolateCode.start,
        options: options,
      ));
    }

    _sendPort!.send(
        IsolateMessage(IsolateCode.prompt, input: input, stream: stream));
  }

  static void stop() {
    _sendPort?.send(IsolateMessage(IsolateCode.stop));
  }

  static void dispose() {
    _sendPort?.send(IsolateMessage(IsolateCode.dispose));
  }
}
