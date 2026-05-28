import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:notification_centre/notification_centre.dart';

import 'package:reins/Constants/constants.dart';
import 'package:reins/Models/chat_configure_arguments.dart';
import 'package:reins/Models/ollama_chat.dart';
import 'package:reins/Models/ollama_exception.dart';
import 'package:reins/Models/ollama_message.dart';
import 'package:reins/Models/ollama_model.dart';
import 'package:reins/Services/database_service.dart';
import 'package:reins/Services/ollama_service.dart';
import 'package:reins/Services/web_search_service.dart';

/// Maximum number of tool-call rounds per user turn.
///
/// Caps runaway loops where a model keeps calling tools without producing a
/// final answer. Each round = (assistant tool_call → execute → tool result).
const int _maxToolRounds = 5;

class ChatProvider extends ChangeNotifier {
  final OllamaService _ollamaService;
  final DatabaseService _databaseService;
  final WebSearchService _webSearchService;

  List<OllamaMessage> _messages = [];
  List<OllamaMessage> get messages => _messages;

  List<OllamaChat> _chats = [];
  List<OllamaChat> get chats => _chats;

  int _currentChatIndex = -1;
  int get selectedDestination => _currentChatIndex + 1;

  OllamaChat? get currentChat =>
      _currentChatIndex == -1 ? null : _chats[_currentChatIndex];

  final Map<String, OllamaMessage?> _activeChatStreams = {};

  bool get isCurrentChatStreaming =>
      _activeChatStreams.containsKey(currentChat?.id);

  bool get isCurrentChatThinking =>
      currentChat != null &&
      _activeChatStreams.containsKey(currentChat?.id) &&
      _activeChatStreams[currentChat?.id] == null;

  /// A map of chat errors, indexed by chat ID.
  final Map<String, OllamaException> _chatErrors = {};

  /// The current chat error. This is the error associated with the current chat.
  /// If there is no error, this will be `null`.
  ///
  /// This is used to display error messages in the chat view.
  OllamaException? get currentChatError => _chatErrors[currentChat?.id];

  /// Human-readable description of the tool currently being invoked.
  ///
  /// Non-null while the agentic loop is executing a tool (e.g. "Using tool
  /// web_search…"). The UI shows this in place of the "Thinking" shimmer so
  /// users see why the assistant is silent.
  String? _currentToolActivity;
  String? get currentToolActivity => _currentToolActivity;

  /// The current chat configuration.
  ChatConfigureArguments get currentChatConfiguration {
    if (currentChat == null) {
      return _emptyChatConfiguration ?? ChatConfigureArguments.defaultArguments;
    } else {
      return ChatConfigureArguments(
        systemPrompt: currentChat!.systemPrompt,
        chatOptions: currentChat!.options,
      );
    }
  }

  /// The chat configuration for the empty chat.
  ChatConfigureArguments? _emptyChatConfiguration;

  ChatProvider({
    required OllamaService ollamaService,
    required DatabaseService databaseService,
    required WebSearchService webSearchService,
  })  : _ollamaService = ollamaService,
        _databaseService = databaseService,
        _webSearchService = webSearchService {
    _initialize();
  }

  /// Whether the agentic web search loop is enabled for the next turn.
  ///
  /// Persisted under Hive `settings['webSearchEnabled']`. Globe toggle in the
  /// chat input drives this.
  bool get isWebSearchEnabled =>
      Hive.box('settings').get('webSearchEnabled', defaultValue: true) as bool;

  Future<void> setWebSearchEnabled(bool value) async {
    await Hive.box('settings').put('webSearchEnabled', value);
    notifyListeners();
  }

  Future<void> _initialize() async {
    _updateOllamaServiceAddress();

    await _databaseService.open("ollama_chat.db");
    _chats = await _databaseService.getAllChats();
    notifyListeners();
  }

  void destinationChatSelected(int destination) {
    _currentChatIndex = destination - 1;

    if (destination == 0) {
      _resetChat();
    } else {
      _loadCurrentChat();
    }

    notifyListeners();
  }

  void _resetChat() {
    _currentChatIndex = -1;

    _messages.clear();

    notifyListeners();
  }

  Future<void> _loadCurrentChat() async {
    _messages = await _databaseService.getMessages(currentChat!.id);

    // Add the streaming message to the chat if it exists
    final streamingMessage = _activeChatStreams[currentChat!.id];
    if (streamingMessage != null) {
      _messages.add(streamingMessage);
    }

    // Unfocus the text field to dismiss the keyboard
    FocusManager.instance.primaryFocus?.unfocus();

    notifyListeners();
  }

  Future<void> createNewChat(OllamaModel model) async {
    final chat = await _databaseService.createChat(model.name);

    _chats.insert(0, chat);
    _currentChatIndex = 0;

    if (_emptyChatConfiguration != null) {
      await updateCurrentChat(
        newSystemPrompt: _emptyChatConfiguration!.systemPrompt,
        newOptions: _emptyChatConfiguration!.chatOptions,
      );

      _emptyChatConfiguration = null;
    }

    notifyListeners();
  }

  Future<void> updateCurrentChat({
    String? newModel,
    String? newTitle,
    String? newSystemPrompt,
    OllamaChatOptions? newOptions,
  }) async {
    await updateChat(
      currentChat,
      newModel: newModel,
      newTitle: newTitle,
      newSystemPrompt: newSystemPrompt,
      newOptions: newOptions,
    );
  }

  /// Updates the chat with the given parameters.
  ///
  /// If the chat is `null`, it updates the empty chat configuration.
  Future<void> updateChat(
    OllamaChat? chat, {
    String? newModel,
    String? newTitle,
    String? newSystemPrompt,
    OllamaChatOptions? newOptions,
  }) async {
    if (chat == null) {
      final chatOptions = newOptions ?? _emptyChatConfiguration?.chatOptions;
      _emptyChatConfiguration = ChatConfigureArguments(
        systemPrompt: newSystemPrompt ?? _emptyChatConfiguration?.systemPrompt,
        chatOptions: chatOptions ?? OllamaChatOptions(),
      );
    } else {
      await _databaseService.updateChat(
        chat,
        newModel: newModel,
        newTitle: newTitle,
        newSystemPrompt: newSystemPrompt,
        newOptions: newOptions,
      );

      final chatIndex = _chats.indexWhere((c) => c.id == chat.id);

      if (chatIndex != -1) {
        _chats[chatIndex] = (await _databaseService.getChat(chat.id))!;
        notifyListeners();
      } else {
        throw OllamaException("Chat not found.");
      }
    }
  }

  Future<void> deleteCurrentChat() async {
    final chat = currentChat;
    if (chat == null) return;

    _resetChat();

    _chats.remove(chat);
    _activeChatStreams.remove(chat.id);

    await _databaseService.deleteChat(chat.id);
  }

  Future<void> sendPrompt(String text, {List<File>? images}) async {
    // Save the chat where the prompt was sent
    final associatedChat = currentChat!;

    // Create a user prompt message and add it to the chat
    final prompt = OllamaMessage(
      text.trim(),
      images: images,
      role: OllamaMessageRole.user,
    );
    _messages.add(prompt);

    notifyListeners();

    // Save the user prompt to the database
    await _databaseService.addMessage(prompt, chat: associatedChat);

    // Initialize the chat stream with the messages in the chat
    await _initializeChatStream(associatedChat);
  }

  Future<void> _initializeChatStream(OllamaChat associatedChat) async {
    // Send a notification to inform generation begin
    NotificationCenter().postNotification(NotificationNames.generationBegin);

    // Clear the active chat streams to cancel the previous stream
    _activeChatStreams.remove(associatedChat.id);

    // Clear the error message associated with the chat
    if (_chatErrors.remove(associatedChat.id) != null) {
      notifyListeners();
      // Wait for a short time to show the user that the error message is cleared
      await Future.delayed(Duration(milliseconds: 250));
    }

    // Update the chat list to show the latest chat at the top
    _moveCurrentChatToTop();

    // Add the chat to the active chat streams to show the thinking indicator
    _activeChatStreams[associatedChat.id] = null;
    // Notify the listeners to show the thinking indicator
    notifyListeners();

    final tools = isWebSearchEnabled ? _buildWebSearchTools() : null;
    // Snapshot the visible conversation at the start of the turn. Tool-round
    // messages (assistant tool_calls + tool results) are appended only to this
    // local list so they reach the API but stay out of the visible chat.
    final apiMessages = List<OllamaMessage>.from(_messages);
    if (tools != null) {
      // Nudge the model to call web_search proactively for time-sensitive
      // queries. Without this, models tend to answer from training data and
      // only search when the user explicitly asks.
      final today = DateTime.now().toUtc().toIso8601String().split('T').first;
      apiMessages.insert(
        0,
        OllamaMessage(
          'Today is $today. Your training data is older than today and is '
          'therefore OUTDATED for anything that changes over time. You have '
          'a web_search tool available.\n\n'
          'HARD RULES:\n'
          '1. For ANY question about the "latest", "current", "newest", or '
          '"most recent" version of a product, person\'s role, price, '
          'score, statistic, event, release, or news item — you MUST call '
          'web_search BEFORE answering. Do not answer from memory.\n'
          '2. After web_search returns results, BASE YOUR ANSWER ON THE '
          'SEARCH RESULTS. Do not contradict them with training-data '
          'knowledge. If the results disagree with what you remember, the '
          'results win.\n'
          '3. Cite source URLs from the search results in your final '
          'answer.',
          role: OllamaMessageRole.system,
        ),
      );
    }
    OllamaMessage? finalMessage;

    try {
      for (var round = 0; round <= _maxToolRounds; round++) {
        if (round > 0) {
          // Reset the streaming slot so a new streaming message is created
          // for this round and the "thinking" indicator reappears between
          // tool execution and the model's next response.
          _activeChatStreams[associatedChat.id] = null;
          notifyListeners();
        }

        final message = await _streamOllamaMessage(
          associatedChat,
          apiMessages: apiMessages,
          tools: tools,
        );

        // The user cancelled mid-stream.
        if (!_activeChatStreams.containsKey(associatedChat.id)) {
          finalMessage = message;
          break;
        }

        if (message == null) break;

        final toolCalls = message.toolCalls;
        if (toolCalls == null || toolCalls.isEmpty || round == _maxToolRounds) {
          finalMessage = message;
          break;
        }

        // Tool round: append the assistant's tool_call turn to the API history
        // (the model needs to see its own tool calls on the next pass) and run
        // each tool, appending results as `tool` role messages — again only to
        // the API list, never to _messages.
        apiMessages.add(message);
        for (final call in toolCalls) {
          final fn = call['function'] as Map?;
          if (fn == null) continue;
          final name = (fn['name'] as String?) ?? '';
          final args = _coerceArguments(fn['arguments']);
          _currentToolActivity = _describeToolActivity(name, args);
          notifyListeners();
          final result = await _executeTool(name, args);
          apiMessages.add(OllamaMessage(
            result,
            role: OllamaMessageRole.tool,
            toolName: name,
          ));
        }
        _currentToolActivity = null;
      }
    } on OllamaException catch (error) {
      _chatErrors[associatedChat.id] = error;
    } on SocketException catch (_) {
      _chatErrors[associatedChat.id] = OllamaException(
        'Network connection lost. Check your server address or internet connection.',
      );
    } catch (error) {
      _chatErrors[associatedChat.id] = OllamaException("Something went wrong.");
    } finally {
      // Remove the chat from the active chat streams
      _activeChatStreams.remove(associatedChat.id);
      _currentToolActivity = null;
      notifyListeners();
    }

    // Persist only the final assistant turn (with text content). Intermediate
    // tool_call assistant turns and tool-role messages stay in memory for the
    // current view but are dropped on chat reload — the DB schema only allows
    // user/assistant/system roles.
    if (finalMessage != null &&
        finalMessage.role == OllamaMessageRole.assistant &&
        finalMessage.content.isNotEmpty) {
      finalMessage.toolCalls = null;
      await _databaseService.addMessage(finalMessage, chat: associatedChat);
    }
  }

  String _describeToolActivity(String name, Map<String, dynamic> args) {
    if (name == 'web_search') {
      final q = (args['query'] as String?)?.trim();
      if (q != null && q.isNotEmpty) return 'Searching the web: "$q"';
      return 'Searching the web…';
    }
    if (name == 'web_fetch') {
      final url = (args['url'] as String?)?.trim();
      if (url != null && url.isNotEmpty) return 'Fetching $url';
      return 'Fetching a page…';
    }
    return 'Using tool $name…';
  }

  Map<String, dynamic> _coerceArguments(dynamic raw) {
    if (raw is Map) return raw.cast<String, dynamic>();
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {}
    }
    return const {};
  }

  /// Definitions of the web tools exposed to the model when web search is on.
  List<Map<String, dynamic>> _buildWebSearchTools() => [
        {
          "type": "function",
          "function": {
            "name": "web_search",
            "description":
                "Search the web for up-to-date information. Use this whenever the user asks about recent events or facts you are not confident about.",
            "parameters": {
              "type": "object",
              "required": ["query"],
              "properties": {
                "query": {
                  "type": "string",
                  "description": "The search query.",
                },
                "max_results": {
                  "type": "integer",
                  "description": "Number of results to return (max 10).",
                },
              },
            },
          },
        },
        {
          "type": "function",
          "function": {
            "name": "web_fetch",
            "description":
                "Fetch the parsed contents of a single URL when you need more detail than a search snippet provides.",
            "parameters": {
              "type": "object",
              "required": ["url"],
              "properties": {
                "url": {
                  "type": "string",
                  "description": "The URL to fetch.",
                },
              },
            },
          },
        },
      ];

  Future<String> _executeTool(
    String name,
    Map<String, dynamic> args,
  ) async {
    try {
      if (name == 'web_search') {
        final query = (args['query'] as String?)?.trim() ?? '';
        if (query.isEmpty) return 'Error: missing query.';
        final maxResults = (args['max_results'] as num?)?.toInt() ?? 5;
        final results = await _webSearchService.search(query, maxResults: maxResults);
        if (results.isEmpty) return 'No results found for "$query".';
        return jsonEncode({
          'results': results
              .map((r) => {
                    'title': r.title,
                    'url': r.url,
                    'content': r.content,
                  })
              .toList(),
        });
      }
      if (name == 'web_fetch') {
        final url = (args['url'] as String?)?.trim() ?? '';
        if (url.isEmpty) return 'Error: missing url.';
        final fetched = await _webSearchService.fetch(url);
        return jsonEncode({
          'title': fetched.title,
          'content': fetched.content,
          'links': fetched.links,
        });
      }
      return 'Error: unknown tool "$name".';
    } on OllamaException catch (e) {
      return 'Error: ${e.message}';
    } catch (_) {
      return 'Error: tool execution failed.';
    }
  }

  Future<OllamaMessage?> _streamOllamaMessage(
    OllamaChat associatedChat, {
    required List<OllamaMessage> apiMessages,
    List<Map<String, dynamic>>? tools,
  }) async {
    if (apiMessages.isEmpty) return null;

    final stream = _ollamaService.chatStream(
      apiMessages,
      chat: associatedChat,
      tools: tools,
    );

    OllamaMessage? streamingMessage;
    OllamaMessage? receivedMessage;
    List<Map<String, dynamic>>? latestToolCalls;

    await for (receivedMessage in stream) {
      // If the chat id is not in the active chat streams, it means the stream
      // is cancelled by the user. So, we need to break the loop.
      if (_activeChatStreams.containsKey(associatedChat.id) == false) {
        streamingMessage?.createdAt = DateTime.now();
        streamingMessage?.toolCalls = latestToolCalls;
        return streamingMessage;
      }

      if (receivedMessage.toolCalls != null && receivedMessage.toolCalls!.isNotEmpty) {
        latestToolCalls = receivedMessage.toolCalls;
      }

      final hasContent = receivedMessage.content.isNotEmpty;

      if (streamingMessage == null) {
        // Skip empty chunks until we see content OR tool_calls — otherwise the
        // thinking indicator would be replaced by an empty bubble.
        if (!hasContent && latestToolCalls == null) continue;

        streamingMessage = receivedMessage;
        _activeChatStreams[associatedChat.id] = streamingMessage;

        // Only show messages with visible text content in the chat list; tool-
        // call-only assistant turns stay invisible and are dropped after the
        // turn finishes.
        if (associatedChat.id == currentChat?.id && hasContent) {
          _messages.add(streamingMessage);
        }
      } else if (hasContent) {
        streamingMessage.content += receivedMessage.content;
      }

      notifyListeners();
    }

    if (receivedMessage != null) {
      // Update the metadata of the streaming message with the last received message
      streamingMessage?.updateMetadataFrom(receivedMessage);
    }

    // Update created at time to the current time when the stream is finished
    streamingMessage?.createdAt = DateTime.now();
    streamingMessage?.toolCalls = latestToolCalls;

    return streamingMessage;
  }

  Future<void> regenerateMessage(OllamaMessage message) async {
    final associatedChat = currentChat!;

    final messageIndex = _messages.indexOf(message);
    if (messageIndex == -1) return;

    final includeMessage = (message.role == OllamaMessageRole.user ? 1 : 0);

    final stayedMessages = _messages.sublist(0, messageIndex + includeMessage);
    final removeMessages = _messages.sublist(messageIndex + includeMessage);

    _messages = stayedMessages;
    notifyListeners();

    await _databaseService.deleteMessages(removeMessages);

    // Reinitialize the chat stream with the messages in the chat
    await _initializeChatStream(associatedChat);
  }

  Future<void> retryLastPrompt() async {
    if (_messages.isEmpty) return;

    final associatedChat = currentChat!;

    if (_messages.last.role == OllamaMessageRole.assistant) {
      final message = _messages.removeLast();
      await _databaseService.deleteMessage(message.id);
    }

    // Reinitialize the chat stream with the messages in the chat
    await _initializeChatStream(associatedChat);

    notifyListeners();
  }

  Future<void> updateMessage(
    OllamaMessage message, {
    String? newContent,
  }) async {
    message.content = newContent ?? message.content;
    notifyListeners();

    await _databaseService.updateMessage(message, newContent: newContent);
  }

  Future<void> deleteMessage(OllamaMessage message) async {
    await _databaseService.deleteMessage(message.id);

    // If the message is in the chat, remove it from the chat
    if (_messages.remove(message)) {
      notifyListeners();
    }
  }

  void cancelCurrentStreaming() {
    _activeChatStreams.remove(currentChat?.id);
    notifyListeners();
  }

  void _moveCurrentChatToTop() {
    if (_currentChatIndex == 0) return;

    final chat = _chats.removeAt(_currentChatIndex);
    _chats.insert(0, chat);
    _currentChatIndex = 0;
  }

  Future<List<OllamaModel>> fetchAvailableModels() async {
    return await _ollamaService.listModels();
  }

  void _updateOllamaServiceAddress() {
    final settingsBox = Hive.box('settings');
    _ollamaService.baseUrl = settingsBox.get('serverAddress');
    _ollamaService.apiToken = settingsBox.get('apiToken');
    _webSearchService.apiToken = settingsBox.get('apiToken');

    settingsBox.listenable(keys: ["serverAddress", "apiToken"]).addListener(() {
      _ollamaService.baseUrl = settingsBox.get('serverAddress');
      _ollamaService.apiToken = settingsBox.get('apiToken');
      _webSearchService.apiToken = settingsBox.get('apiToken');

      // This will update empty chat state to dismiss "Tap to configure server address" message
      notifyListeners();
    });
  }

  Future<void> saveAsNewModel(String modelName) async {
    final associatedChat = currentChat;
    if (associatedChat == null) {
      // TODO: Empty chat should be saved as a new model.
      throw OllamaException("No chat is selected.");
    }

    await _ollamaService.createModel(
      modelName,
      chat: associatedChat,
      messages: _messages.toList(),
    );
  }

  Future<void> generateTitleForCurrentChat() async {
    final associatedChat = currentChat;
    final message = _messages.firstOrNull;
    if (associatedChat == null || message == null) return;

    // Create a temp chat with necessary system prompt
    final chat = OllamaChat(
      model: associatedChat.model,
      systemPrompt: GenerateTitleConstants.systemPrompt,
    );

    // Generate a title for the message
    final stream = _ollamaService.generateStream(
      GenerateTitleConstants.prompt + message.content,
      chat: chat,
    );

    var title = "";
    await for (final titleMessage in stream) {
      // Ignore empty initial messages, preventing empty title
      if (title.isEmpty && titleMessage.content.isEmpty) {
        continue;
      }

      title += titleMessage.content;

      // If <think> tag exists, do not stream chat title
      if (title.startsWith("<think>")) {
        await updateChat(associatedChat, newTitle: "Thinking for a title...");
      } else {
        await updateChat(associatedChat, newTitle: title);
      }
    }

    // Remove <think> tag and its content
    if (title.startsWith("<think>")) {
      title = title.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '');
    }

    // Save the title as the chat title
    await updateChat(associatedChat, newTitle: title.trim());
  }
}
