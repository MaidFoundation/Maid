import 'dart:math';

import 'package:maid/classes/llm.dart';
import 'package:maid_llm/maid_llm.dart';

class LlamaCppModel extends LLM {
  late String path;

  late int nKeep;
  late int nCtx;
  late int nBatch;
  late int nThread;
  late int nPredict;
  late int topK;
  late int penaltyLastN;
  late int mirostat;

  late double topP;
  late double minP;
  late double tfsZ;
  late double typicalP;
  late double penaltyRepeat;
  late double penaltyPresent;
  late double penaltyFreq;
  late double mirostatTau;
  late double mirostatEta;

  late bool penalizeNewline;

  late PromptFormat promptFormat;
  
  LlamaCppModel({
    super.seed, 
    super.temperature, 
    this.path = '',
    this.nKeep = 48,
    this.nCtx = 512,
    this.nBatch = 512,
    this.nThread = 8,
    this.nPredict = 512,
    this.topK = 40, 
    this.penaltyLastN = 64, 
    this.mirostat = 0,
    this.topP = 0.95,
    this.minP = 0.1,
    this.tfsZ = 1.0,
    this.typicalP = 1.0,
    this.penaltyRepeat = 1.1,
    this.penaltyPresent = 0.0,
    this.penaltyFreq = 0.0,
    this.mirostatTau = 5.0,
    this.mirostatEta = 0.1,
    this.penalizeNewline = true,
    this.promptFormat = PromptFormat.alpaca
  });

  LlamaCppModel.fromJson(Map<String, dynamic> json) {
    fromJson(json);
  }

  @override
  void fromJson(Map<String, dynamic> json) {
    seed = json['seed'] ?? 0;
    temperature = json['temperature'] ?? 0.8;
    path = json['path'] ?? '';
    nKeep = json['nKeep'] ?? 48;
    nCtx = json['nCtx'] ?? 512;
    nBatch = json['nBatch'] ?? 512;
    nThread = json['nThread'] ?? 8;
    nPredict = json['nPredict'] ?? 512;
    topK = json['topK'] ?? 40;
    penaltyLastN = json['penaltyLastN'] ?? 64;
    mirostat = json['mirostat'] ?? 0;
    topP = json['topP'] ?? 0.95;
    minP = json['minP'] ?? 0.1;
    tfsZ = json['tfsZ'] ?? 1.0;
    typicalP = json['typicalP'] ?? 1.0;
    penaltyRepeat = json['penaltyRepeat'] ?? 1.1;
    penaltyPresent = json['penaltyPresent'] ?? 0.0;
    penaltyFreq = json['penaltyFreq'] ?? 0.0;
    mirostatTau = json['mirostatTau'] ?? 5.0;
    mirostatEta = json['mirostatEta'] ?? 0.1;
    penalizeNewline = json['penalizeNewline'] ?? true;
    promptFormat = json['promptFormat'] ?? PromptFormat.alpaca;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'seed': seed,
      'temperature': temperature,
      'path': path,
      'nKeep': nKeep,
      'nCtx': nCtx,
      'nBatch': nBatch,
      'nThread': nThread,
      'nPredict': nPredict,
      'topK': topK,
      'penaltyLastN': penaltyLastN,
      'mirostat': mirostat,
      'topP': topP,
      'minP': minP,
      'tfsZ': tfsZ,
      'typicalP': typicalP,
      'penaltyRepeat': penaltyRepeat,
      'penaltyPresent': penaltyPresent,
      'penaltyFreq': penaltyFreq,
      'mirostatTau': mirostatTau,
      'mirostatEta': mirostatEta,
      'penalizeNewline': penalizeNewline,
      'promptFormat': promptFormat
    };
  }

  GptParams toGptParams() {
    SamplingParams samplingParams = SamplingParams();
    samplingParams.temp = temperature;
    samplingParams.topK = topK;
    samplingParams.topP = topP;
    samplingParams.tfsZ = tfsZ;
    samplingParams.typicalP = typicalP;
    samplingParams.penaltyLastN = penaltyLastN;
    samplingParams.penaltyRepeat = penaltyRepeat;
    samplingParams.penaltyFreq = penaltyFreq;
    samplingParams.penaltyPresent = penaltyPresent;
    samplingParams.mirostat = mirostat;
    samplingParams.mirostatTau = mirostatTau;
    samplingParams.mirostatEta = mirostatEta;
    samplingParams.penalizeNl = penalizeNewline;

    GptParams gptParams = GptParams();
    gptParams.seed = seed != 0 ? seed : Random().nextInt(1000000);
    gptParams.nThreads = nThread;
    gptParams.nThreadsBatch = nThread;
    gptParams.nPredict = nPredict;
    gptParams.nCtx = nCtx;
    gptParams.nBatch = nBatch;
    gptParams.nKeep = nKeep;
    gptParams.sparams = samplingParams;
    gptParams.model = path;
    gptParams.instruct = promptFormat == PromptFormat.alpaca;
    gptParams.chatml = promptFormat == PromptFormat.chatml;

    return gptParams;
  }
}