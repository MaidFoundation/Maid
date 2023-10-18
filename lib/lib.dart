/// run.dart
import 'dart:async';
import 'dart:io';

import 'dart:ffi';
import 'dart:ffi' as ffi;
import 'dart:isolate';
import 'package:ffi/ffi.dart';

import 'package:flutter/services.dart';
import 'package:maid/model.dart';

import 'package:maid/butler.dart';

// Unimplemented
class Lib2 {
  late NativeLibrary _nativeLibrary;

  // Make the default constructor private
  Lib2._();

  // Private reference to the global instance
  static final Lib2 _instance = Lib2._();

  // Public accessor to the global instance
  static Lib2 get instance {
    _instance._initialize();
    return _instance;
  }

  // Flag to check if the instance has been initialized
  bool _isInitialized = false;

  // Initialization logic
  void _initialize() {
    if (!_isInitialized) {
      _loadNativeLibrary();
      _isInitialized = true;
    }
  }

  void _loadNativeLibrary() {
    DynamicLibrary butlerDynamic =
        Platform.isMacOS || Platform.isIOS
            ? DynamicLibrary.process() // macos and ios
            : (DynamicLibrary.open(
                Platform.isWindows // windows
                    ? 'butler.dll'
                    : 'libbutler.so')); // android and linux

    _nativeLibrary = NativeLibrary(butlerDynamic);
  }

  Future<int> butlerStartAsync() {
    return Future<int>(() {
      final params = calloc<butler_params>();
      params.ref.model_path = model.modelPath.toNativeUtf8().cast<Char>();
      params.ref.prompt = model.prePrompt.toNativeUtf8().cast<Char>();
      params.ref.antiprompt = model.reversePromptController.text.trim().toNativeUtf8().cast<Char>();
      
      return _nativeLibrary.butler_start(params);
    });
  }

  Future<int> butlerContinueAsync(ffi.Pointer<maid_output_cb> maidOutput) {
    return Future<int>(() {
      ffi.Pointer<ffi.Char> input = model.promptController.text.trim().toNativeUtf8().cast<Char>();
      return _nativeLibrary.butler_continue(input, maidOutput);
    });
  }

  void butlerStop() {
    _nativeLibrary.butler_stop();
  }

  void butlerExit() {
    _nativeLibrary.butler_exit();
  }
}

class Lib {
  Lib();

  Future<NativeLibrary> loadButler() async {
    DynamicLibrary butler =
        Platform.isMacOS || Platform.isIOS
          ? DynamicLibrary.process() // macos and ios
          : (DynamicLibrary.open(
              Platform.isWindows // windows
                ? 'butler.dll'
                : 'libbutler.so')); // android and linux

    return NativeLibrary(butler);
  }

  static parserIsolateFunction(
    SendPort mainSendPort,
  ) async {
    ReceivePort isolateReceivePort = ReceivePort();
    SendPort isolateSendPort = isolateReceivePort.sendPort;
    mainSendPort.send(isolateSendPort);
    var completer = Completer<ParsingDemand>();
    try {
      isolateReceivePort.listen((signal) async {
        if (signal.type == SignalType.NewPrompt) {
          interaction.complete(signal.data);
        }
        if (signal.type == SignalType.ParsingDemand) {
          // mainSendPort.send(ParsingResult(fileSaved.path));
          completer.complete(signal);
        }
      });

      var parsingDemand = await completer.future;
      Future.sync(() => Lib().binaryIsolate(
            parsingDemand: parsingDemand,
            antiprompt: parsingDemand.antiprompt,
            mainSendPort: mainSendPort,
          ));
    } catch (e) {
      mainSendPort.send("[isolate] ERROR : $e");
    }
  }

  Future<void> newPrompt(String prompt) async {
    isolateSendPort?.send(Signal.newPrompt(prompt));
  }

  ReceivePort mainReceivePort = ReceivePort();

  SendPort? mainSendPort;
  SendPort? isolateSendPort;

  Future<void> executeBinary({
    required Model model,
    required void Function(String log) printLog,
    required String promptPassed,
    required String firstInteraction,
    required void Function() done,
    required void Function() canStop,
    required String antiprompt,
    required ParamsLlama paramsLlama,
  }) async {
    RootIsolateToken? token = ServicesBinding.rootIsolateToken;
    mainSendPort = mainReceivePort.sendPort;
    await runZonedGuarded<Future>(
        () => Isolate.spawn(parserIsolateFunction, mainSendPort!),
        (error, stack) {});

    Completer completer = Completer();

    mainReceivePort.listen((signal) {
      if (signal is SendPort) {
        isolateSendPort = signal;
        isolateSendPort?.send(ParsingDemand(
          modelPath: model.modelPath,
          rootIsolateToken: token,
          promptPassed: promptPassed,
          firstInteraction: firstInteraction,
          antiprompt: antiprompt,
          paramsLlama: paramsLlama,
        ));
      } else if (signal.type == SignalType.EndFromIsolate) {
        completer.complete();
      } else if (signal.type == SignalType.FromIsolate) {
        printLog(signal.data);
      } else if (signal.type == SignalType.CanStop) {
        canStop();
      } else {
        print(signal);
      }
    });
    await completer.future;
    done();
    cancel();
  }

  static SendPort? mainPort;

  static Completer interaction = Completer();

  static void showOutput(Pointer<Char> output) {
    try {
      mainPort?.send(
        Signal.fromIsolate(output.cast<Utf8>().toDartString())
      );
    } catch (e) {
      print(e.toString());
    }
  }

  void binaryIsolate({
    required ParsingDemand parsingDemand,
    required SendPort mainSendPort,
    required String antiprompt,
  }) async {
    interaction.complete();
    mainPort = mainSendPort;
    if (parsingDemand.rootIsolateToken == null) return;
    BackgroundIsolateBinaryMessenger.ensureInitialized(
        parsingDemand.rootIsolateToken!);

    var modelPathUtf8 = parsingDemand.modelPath?.toNativeUtf8().cast<Char>();
    if (modelPathUtf8 == null) {
      print("modelPath is null");
      return;
    }

    var firstInteraction = parsingDemand.firstInteraction;
    interaction = Completer();

    Pointer<maid_output_cb> maidOutput = Pointer.fromFunction(showOutput);

    NativeLibrary butlerBinded = await loadButler();
    final params = calloc<butler_params>();
    params.ref.model_path = modelPathUtf8;
    params.ref.prompt = parsingDemand.promptPassed.toNativeUtf8().cast<Char>();
    params.ref.antiprompt = parsingDemand.antiprompt.trim().toNativeUtf8().cast<Char>();

    butlerBinded.butler_start(params);

    print('FirstInteraction: $firstInteraction');
    // if first line of conversation was provided, pass it now
    if (firstInteraction.isNotEmpty) {
      butlerBinded.butler_continue(firstInteraction.toNativeUtf8().cast<Char>(), maidOutput);
    }

    while (true) {
      String buffer = await interaction.future;
      interaction = Completer();
      // process user input
      butlerBinded.butler_continue(buffer.toNativeUtf8().cast<Char>(), maidOutput);
    }
  }

  void cancel() async {
    NativeLibrary butlerBinded = await loadButler();
    butlerBinded.butler_stop();
  }
}

// Single Signal class that encompasses all the different data types
class Signal {
  final SignalType type;
  final String? data; // We'll use this field for data or prompt data

  // Factory constructors allow us to easily create different signals
  factory Signal.stopGeneration() => Signal._(SignalType.StopGeneration);
  factory Signal.fromIsolate(String data) => Signal._(SignalType.FromIsolate, data);
  factory Signal.newLineFromIsolate(String data) => Signal._(SignalType.NewLineFromIsolate, data);
  factory Signal.endFromIsolate() => Signal._(SignalType.EndFromIsolate);
  factory Signal.canPrompt() => Signal._(SignalType.CanPrompt);
  factory Signal.canStop() => Signal._(SignalType.CanStop);
  factory Signal.newPrompt(String data) => Signal._(SignalType.NewPrompt, data);

  // Private constructor
  Signal._(this.type, [this.data]);
}

class ParsingDemand {
  final SignalType type = SignalType.ParsingDemand;
  String? modelPath;
  RootIsolateToken? rootIsolateToken;
  String promptPassed;
  String firstInteraction;
  String antiprompt;
  ParamsLlama paramsLlama;

  ParsingDemand({
    required this.modelPath,
    required this.rootIsolateToken,
    required this.promptPassed,
    required this.firstInteraction,
    required this.antiprompt,
    required this.paramsLlama,
  });
}

class ParamsLlama {
  bool memory_f16;
  bool random_prompt;
  bool use_color;
  bool interactive;
  bool interactive_start;
  bool instruct;
  bool ignore_eos;
  bool perplexity;
  String seed;
  String n_threads;
  String n_predict;
  String repeat_last_n;
  String n_parts;
  String n_ctx;
  String top_k;
  String top_p;
  String temp;
  String repeat_penalty;
  String n_batch;

  ParamsLlama({
    required this.memory_f16,
    required this.random_prompt,
    required this.use_color,
    required this.interactive,
    required this.interactive_start,
    required this.instruct,
    required this.ignore_eos,
    required this.perplexity,
    required this.seed,
    required this.n_threads,
    required this.n_predict,
    required this.repeat_last_n,
    required this.n_parts,
    required this.n_ctx,
    required this.top_k,
    required this.top_p,
    required this.temp,
    required this.repeat_penalty,
    required this.n_batch,
  });
}

// Enum to represent the different signal types
enum SignalType {
  StopGeneration,
  FromIsolate,
  NewLineFromIsolate,
  EndFromIsolate,
  CanPrompt,
  CanStop,
  NewPrompt,
  ParsingDemand,
}

enum FileState {
  notFound,
  found,
  opening,
}