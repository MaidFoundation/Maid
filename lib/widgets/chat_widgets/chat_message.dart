import 'package:flutter/material.dart';
import 'package:maid/providers/character.dart';
import 'package:maid/providers/session.dart';

import 'package:maid/widgets/chat_widgets/code_box.dart';
import 'package:maid/widgets/chat_widgets/typing_indicator.dart';
import 'package:provider/provider.dart';

class ChatMessage extends StatefulWidget {
  final bool userGenerated;

  const ChatMessage({
    required super.key,
    this.userGenerated = false,
  });

  @override
  ChatMessageState createState() => ChatMessageState();
}

class ChatMessageState extends State<ChatMessage>
    with SingleTickerProviderStateMixin {
  final List<Widget> _messageWidgets = [];
  late Session session;
  TextEditingController _messageController = TextEditingController();
  bool _finalised = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    session = context.read<Session>();

    if (session.getMessage(widget.key!).isNotEmpty) {
      _messageController.text = session.getMessage(widget.key!);
      _parseMessage(_messageController.text);
      _finalised = true;
    } else {
      session.getMessageStream(widget.key!).stream.listen((textChunk) {
        setState(() {
          _messageController.text += textChunk;
          _messageWidgets.clear();
          _parseMessage(_messageController.text);
        });
      });

      session.getFinaliseStream(widget.key!).stream.listen((_) {
        setState(() {
          _messageController.text = _messageController.text.trim();
          _parseMessage(_messageController.text);
          session.add(widget.key!,
              message: _messageController.text, userGenerated: widget.userGenerated);
          _finalised = true;
        });
      });
    }
  }

  void _parseMessage(String message) {
    _messageWidgets.clear();
    List<String> parts = message.split('```');
    for (int i = 0; i < parts.length; i++) {
      String part = parts[i].trim();
      if (part.isEmpty) continue;

      if (i % 2 == 0) {
        _messageWidgets.add(SelectableText(part));
      } else {
        _messageWidgets.add(CodeBox(code: part));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (_finalised || _editing)
        Consumer<Session>(
          builder: (context, session, child) {
            int currentIndex = session.index(widget.key!);
            int siblingCount = session.siblingCount(widget.key!);

            return Row(
              mainAxisAlignment: widget.userGenerated
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
              children: [
                if (_finalised)
                  ...[
                    if (widget.userGenerated)
                      IconButton(
                        padding: const EdgeInsets.all(0),
                        onPressed: () {
                          if (session.isBusy) return;
                          setState(() {
                            _editing = true;
                            _finalised = false;
                          });
                        },
                        icon: const Icon(Icons.edit),
                      )
                    else
                      ...[
                        const SizedBox(width: 10.0),
                        CircleAvatar(
                          backgroundImage: const AssetImage("assets/default_profile.png"),
                          foregroundImage: Image.file(context.read<Character>().profile).image,
                          radius: 16,
                        ),
                        const SizedBox(width: 10.0),
                        Text(
                          context.read<Character>().name,
                          style: Theme.of(context).textTheme.labelLarge,
                        )
                      ],
                    if (siblingCount > 1)
                      Container(
                        alignment: Alignment.center,
                        margin: const EdgeInsets.all(10),
                        padding: const EdgeInsets.all(0),
                        width: 150,
                        height: 30,
                        decoration: BoxDecoration(
                          color: session.isBusy 
                               ? Theme.of(context).colorScheme.primary 
                               : Theme.of(context).colorScheme.tertiary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            IconButton(
                              padding: const EdgeInsets.all(0),
                              onPressed: () {
                                if (session.isBusy) return;
                                session.last(widget.key!);
                              },
                              icon: Icon(
                                Icons.arrow_left, 
                                color: Theme.of(context).colorScheme.onPrimary
                              )
                            ),
                            Text('$currentIndex/${siblingCount-1}', style: Theme.of(context).textTheme.labelLarge),
                            IconButton(
                              padding: const EdgeInsets.all(0),
                              onPressed: () {
                                if (session.isBusy) return;
                                session.next(widget.key!);
                              },
                              icon: Icon(
                                Icons.arrow_right,
                                color: Theme.of(context).colorScheme.onPrimary),
                            ),
                          ],
                        ),
                      ),
                    if (!widget.userGenerated)
                      IconButton(
                        padding: const EdgeInsets.all(0),
                        onPressed: () {
                          if (session.isBusy) return;
                          session.regenerate(
                            widget.key!,
                            context
                          );
                          setState(() {});
                        },
                        icon: const Icon(Icons.refresh),
                      ),
                  ]
                else
                  IconButton(
                    padding: const EdgeInsets.all(0),
                    onPressed: () {
                      setState(() {
                        _editing = false;
                        _finalised = true;
                      });
                    }, 
                    icon: const Icon(Icons.done)
                  ),
              ],
            );
          },
        ),        
      Align(
        alignment:
            widget.userGenerated ? Alignment.centerRight : Alignment.centerLeft,
        child: _editing ? 
          Padding(padding: const EdgeInsets.all(10),
            child: TextField(
              controller: _messageController,
              autofocus: true,
              cursorColor: Theme.of(context).colorScheme.tertiary,
              decoration: InputDecoration(
                hintText: "Edit Message",
                fillColor: Theme.of(context).colorScheme.secondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide.none,
                )
              ),
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
          ) :
          Container(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: widget.userGenerated
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_finalised && _messageWidgets.isEmpty)
                const TypingIndicator()
              else
                ..._messageWidgets,
            ],
          )
        ),
      )
    ]);
  }

  @override
  void dispose() {
    session.getMessageStream(widget.key!).close();
    session.getFinaliseStream(widget.key!).close();
    super.dispose();
  }
}
