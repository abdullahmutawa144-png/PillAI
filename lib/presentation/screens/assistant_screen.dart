import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/app_models.dart';
import '../../domain/app_store.dart';
import '../../domain/assistant_engine.dart';
import '../../domain/assistant_gateway.dart';
import '../../domain/voice_input.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'dose_sheets.dart';
import '../bidi.dart';

/// Where an assistant reply's action button can take the user.
enum AssistantDestination { today, medicines, healthProfile }

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    required this.store,
    required this.voiceInput,
    required this.assistantGateway,
    required this.voiceRequestId,
    required this.onPromptConsumed,
    required this.onNavigate,
    this.initialPrompt,
    this.initialDraft,
    super.key,
  });

  final AppStore store;
  final VoiceInputController voiceInput;
  final AssistantGateway assistantGateway;
  final int voiceRequestId;

  /// Sent automatically when the screen opens with it.
  final String? initialPrompt;

  /// Placed in the composer for the user to finish.
  final String? initialDraft;
  final VoidCallback onPromptConsumed;
  final ValueChanged<AssistantDestination> onNavigate;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final _fallbackEngine = const DemoAssistantEngine();
  bool _isThinking = false;
  bool _consentSheetOpen = false;
  String _voiceDraftPrefix = '';
  String? _lastConsumedPrompt;
  String? _lastConsumedDraft;
  int _lastVoiceRequestId = 0;

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    widget.voiceInput.addListener(_onVoiceChanged);
    _controller.addListener(_onDraftChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeRequests());
  }

  @override
  void didUpdateWidget(covariant AssistantScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.voiceInput != widget.voiceInput) {
      oldWidget.voiceInput.removeListener(_onVoiceChanged);
      widget.voiceInput.addListener(_onVoiceChanged);
    }
    if (widget.initialPrompt != oldWidget.initialPrompt ||
        widget.initialDraft != oldWidget.initialDraft ||
        widget.voiceRequestId != oldWidget.voiceRequestId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _consumeRequests());
    }
  }

  @override
  void dispose() {
    widget.voiceInput.removeListener(_onVoiceChanged);
    unawaited(widget.voiceInput.cancel());
    _controller
      ..removeListener(_onDraftChanged)
      ..dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onVoiceChanged() {
    if (mounted) setState(() {});
  }

  void _onDraftChanged() {
    if (mounted) setState(() {});
  }

  void _consumeRequests() {
    if (!mounted) return;
    final prompt = widget.initialPrompt;
    final draft = widget.initialDraft;
    if (prompt != null && prompt != _lastConsumedPrompt) {
      _lastConsumedPrompt = prompt;
      widget.onPromptConsumed();
      unawaited(_send(prompt));
    } else if (draft != null && draft != _lastConsumedDraft) {
      _lastConsumedDraft = draft;
      widget.onPromptConsumed();
      _controller.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
      _focusNode.requestFocus();
    }
    if (widget.voiceRequestId != 0 &&
        widget.voiceRequestId != _lastVoiceRequestId) {
      _lastVoiceRequestId = widget.voiceRequestId;
      unawaited(_toggleVoice());
    }
  }

  // ---------------------------------------------------------------------------
  // Voice

  Future<void> _toggleVoice() async {
    if (widget.voiceInput.isListening) {
      await widget.voiceInput.stop();
      return;
    }
    if (!store.voiceNoticeAccepted) {
      final accepted = await showAppSheet<bool>(
        context: context,
        builder: (context) => const _VoiceNoticeSheet(),
      );
      if (accepted != true || !mounted) return;
      store.acceptVoiceNotice();
    }

    _voiceDraftPrefix = _controller.text.trim();
    await widget.voiceInput.start(
      localeId: store.isArabic ? 'ar_SA' : 'en_US',
      onTranscript: (transcript) {
        if (!mounted) return;
        final spoken = transcript.text.trim();
        final combined = [
          if (_voiceDraftPrefix.isNotEmpty) _voiceDraftPrefix,
          if (spoken.isNotEmpty) spoken,
        ].join(' ');
        _controller.value = TextEditingValue(
          text: combined,
          selection: TextSelection.collapsed(offset: combined.length),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Sending

  bool get _maySendRemotely {
    final gateway = widget.assistantGateway;
    return gateway is RemoteAwareAssistantGateway &&
        (gateway as RemoteAwareAssistantGateway).maySendRemotely;
  }

  Future<void> _send([String? supplied]) async {
    final s = AppStrings.of(context);
    final prompt = (supplied ?? _controller.text).trim();
    if (prompt.isEmpty || _isThinking) return;
    if (prompt.length > AssistantRequestLimits.messageCharacters) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.tooLong)));
      return;
    }
    // Emergency wording is answered on the device before anything else,
    // including the consent question.
    final localPreflight = _fallbackEngine.replyTo(prompt, store);
    final isEmergency = localPreflight.level == SafetyLevel.urgent;

    if (!isEmergency && _maySendRemotely && store.remoteAiConsent == null) {
      if (_consentSheetOpen) return;
      _consentSheetOpen = true;
      final decision = await showAppSheet<bool>(
        context: context,
        builder: (context) => const _ConsentSheet(),
      );
      _consentSheetOpen = false;
      if (!mounted || decision == null) return;
      store.setRemoteAiConsent(decision);
    }
    final useLocalOnly = store.remoteAiConsent == false;

    final history = List<ChatMessage>.of(store.messages);
    _controller.clear();
    store.addMessage(
      ChatMessage(text: prompt, isUser: true, sentAt: store.now),
    );
    setState(() => _isThinking = true);
    _scrollToEnd();

    late final AssistantGatewayResponse response;
    try {
      response = isEmergency
          ? AssistantGatewayResponse(
              reply: localPreflight,
              source: AssistantResponseSource.emergencyLocal,
            )
          : useLocalOnly
          ? AssistantGatewayResponse(
              reply: localPreflight,
              source: AssistantResponseSource.demoFallback,
              fallbackReason: AssistantFallbackReason.userChoseLocal,
            )
          : await widget.assistantGateway.replyTo(
              prompt,
              store,
              history: history,
            );
    } on AssistantGatewayException catch (error) {
      response = AssistantGatewayResponse(
        reply: localPreflight,
        source: AssistantResponseSource.demoFallback,
        fallbackReason: error.reason,
      );
    } on Object {
      // A gateway bug must never strand the composer. Keep a safe answer and
      // do not expose technical details.
      response = AssistantGatewayResponse(
        reply: _fallbackEngine.replyTo(prompt, store),
        source: AssistantResponseSource.demoFallback,
        fallbackReason: AssistantFallbackReason.invalidResponse,
      );
    }
    if (!mounted) return;
    store.applyAssistantEffects(
      memoryUpdates: response.memoryUpdates,
      doseEvent: response.doseEvent,
      scheduleProposal: response.scheduleProposal,
    );
    store.addMessage(
      ChatMessage(
        text: response.reply.message,
        isUser: false,
        sentAt: store.now,
        reply: response.reply,
        provenance: response.provenance,
      ),
    );
    setState(() => _isThinking = false);
    _scrollToEnd();

    final proposal = response.scheduleProposal;
    if (proposal != null && mounted) {
      final apply = await showProposalSheet(context, proposal);
      if (!mounted || apply == null) return;
      if (apply) {
        store.confirmReschedule();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.remindersUpdated)));
      } else {
        store.dismissProposal();
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  void _handleAction(AssistantReply reply) {
    if (reply.level == SafetyLevel.urgent) {
      unawaited(showEmergencySheet(context));
      return;
    }
    final destination = _destinationFor(reply.actionLabel);
    if (destination != null) widget.onNavigate(destination);
  }

  // ---------------------------------------------------------------------------
  // Layout

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            AnimatedBuilder(
              animation: store,
              builder: (context, _) {
                final (status, live) = _connectionStatus(s);
                return _AssistantHeader(
                  status: status,
                  live: live,
                  onEmergency: () => showEmergencySheet(context),
                  onNewChat: store.clearConversation,
                  onAbout: _showAbout,
                );
              },
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: store,
                builder: (context, _) {
                  final messages = store.messages;
                  if (messages.isEmpty && !_isThinking) {
                    return _AssistantWelcome(onSend: _send);
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: messages.length + (_isThinking ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        return const _ThinkingBubble();
                      }
                      final message = messages[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: message.isUser
                            ? _UserBubble(text: message.text)
                            : _AssistantBubble(
                                message: message,
                                onAction: message.reply == null
                                    ? null
                                    : () => _handleAction(message.reply!),
                                onUseSuggestion: (text) {
                                  _controller.value = TextEditingValue(
                                    text: text,
                                    selection: TextSelection.collapsed(
                                      offset: text.length,
                                    ),
                                  );
                                  _focusNode.requestFocus();
                                },
                              ),
                      );
                    },
                  );
                },
              ),
            ),
            // At very large text sizes the composer scrolls rather than
            // squeezing the conversation to nothing.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * .5,
              ),
              child: SingleChildScrollView(
                child: _Composer(
                  controller: _controller,
                  focusNode: _focusNode,
                  voiceInput: widget.voiceInput,
                  isThinking: _isThinking,
                  onSend: () => _send(),
                  onToggleVoice: _toggleVoice,
                  onCancelVoice: widget.voiceInput.cancel,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// What the header dot says: live answers, or why answers are local.
  (String, bool) _connectionStatus(AppStrings s) {
    if (!_maySendRemotely || store.remoteAiConsent == false) {
      return (s.statusOffline, false);
    }
    final lastAnswer = store.messages.lastWhere(
      (message) => !message.isUser && message.provenance != null,
      orElse: () => ChatMessage(text: '', isUser: true, sentAt: store.now),
    );
    final provenance = lastAnswer.provenance;
    if (provenance?.source == AssistantResponseSource.demoFallback) {
      return (s.statusUnreachable, false);
    }
    return (
      store.remoteAiConsent == true ? s.statusSmart : s.statusReady,
      true,
    );
  }

  void _showAbout() {
    showAppSheet<void>(
      context: context,
      builder: (sheetContext) => _AboutSheet(store: store),
    );
  }
}

AssistantDestination? _destinationFor(String? actionLabel) {
  return switch (actionLabel) {
    'Review medication list' => AssistantDestination.medicines,
    'Review safety profile' => AssistantDestination.healthProfile,
    "Open today's doses" || 'View schedule' => AssistantDestination.today,
    _ => null,
  };
}

String? _destinationLabel(AppStrings s, AssistantReply reply) {
  if (reply.level == SafetyLevel.urgent) return s.emergencyNumbers;
  return switch (_destinationFor(reply.actionLabel)) {
    AssistantDestination.medicines => s.openMedicines,
    AssistantDestination.healthProfile => s.openHealthProfile,
    AssistantDestination.today => s.openToday,
    null => null,
  };
}

String _friendlyModel(String? model) {
  final normalized = model?.trim().toLowerCase() ?? '';
  if (normalized.startsWith('gpt-5.6-terra')) return 'GPT-5.6 Terra';
  if (normalized.startsWith('gpt-5.6-sol')) return 'GPT-5.6 Sol';
  if (normalized.startsWith('gpt-5.6-luna')) return 'GPT-5.6 Luna';
  if (normalized.startsWith('gpt-5.4-nano')) return 'GPT-5.4 Nano';
  return model?.trim().isNotEmpty == true ? model!.trim() : 'AI';
}

String _provenanceLabel(AppStrings s, AssistantAnswerProvenance provenance) {
  return switch (provenance.source) {
    AssistantResponseSource.liveModel => s.provenanceLive(
      _friendlyModel(provenance.model),
    ),
    AssistantResponseSource.emergencyLocal => s.provenanceEmergency,
    AssistantResponseSource.safetyGuard => s.provenanceSafety,
    AssistantResponseSource.demoFallback =>
      provenance.fallbackReason == AssistantFallbackReason.userChoseLocal
          ? s.provenanceOfflineChoice
          : s.provenanceOffline,
  };
}

class _AssistantHeader extends StatelessWidget {
  const _AssistantHeader({
    required this.status,
    required this.live,
    required this.onEmergency,
    required this.onNewChat,
    required this.onAbout,
  });

  final String status;
  final bool live;
  final VoidCallback onEmergency;
  final VoidCallback onNewChat;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
      child: Row(
        children: [
          const PillAiMark(size: 42, showOnlineBadge: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.appName, style: text.titleLarge),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: live ? AppColors.mintBright : AppColors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (MediaQuery.textScalerOf(context).scale(16) > 24)
            IconButton(
              tooltip: s.emergency,
              onPressed: onEmergency,
              style: IconButton.styleFrom(
                foregroundColor: AppColors.danger,
                backgroundColor: AppColors.dangerSoft,
              ),
              icon: const Icon(Icons.emergency_rounded),
            )
          else
            TextButton.icon(
              onPressed: onEmergency,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
                backgroundColor: AppColors.dangerSoft,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.emergency_rounded, size: 18),
              label: Text(s.emergency),
            ),
          PopupMenuButton<int>(
            tooltip: s.moreOptions,
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) => value == 0 ? onNewChat() : onAbout(),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 0,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.add_comment_outlined),
                  title: Text(s.newChat),
                ),
              ),
              PopupMenuItem(
                value: 1,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.shield_outlined),
                  title: Text(s.aboutAndPrivacy),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssistantWelcome extends StatelessWidget {
  const _AssistantWelcome({required this.onSend});

  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final text = Theme.of(context).textTheme;
    const icons = [
      Icons.local_cafe_outlined,
      Icons.history_rounded,
      Icons.join_inner_rounded,
      Icons.calendar_today_rounded,
    ];
    final suggestions = s.suggestions;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      children: [
        const Center(child: PillAiMark(size: 72)),
        const SizedBox(height: 16),
        Text(
          s.assistantEmptyTitle,
          textAlign: TextAlign.center,
          style: text.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          s.assistantEmptyBody,
          textAlign: TextAlign.center,
          style: text.bodyMedium,
        ),
        const SizedBox(height: 22),
        for (var i = 0; i < suggestions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                side: const BorderSide(color: AppColors.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.md),
                onTap: () => onSend(suggestions[i].$2),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icons[i % icons.length],
                        color: AppColors.ai,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(suggestions[i].$1, style: text.titleMedium),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.inkSubtle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        margin: const EdgeInsetsDirectional.only(start: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadiusDirectional.only(
            topStart: Radius.circular(20),
            topEnd: Radius.circular(20),
            bottomStart: Radius.circular(20),
            bottomEnd: Radius.circular(6),
          ),
        ),
        child: Text(
          text,
          textDirection: directionOf(text),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatefulWidget {
  const _AssistantBubble({
    required this.message,
    required this.onAction,
    required this.onUseSuggestion,
  });

  final ChatMessage message;
  final VoidCallback? onAction;
  final ValueChanged<String> onUseSuggestion;

  @override
  State<_AssistantBubble> createState() => _AssistantBubbleState();
}

class _AssistantBubbleState extends State<_AssistantBubble> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final text = Theme.of(context).textTheme;
    final reply = widget.message.reply;
    final level = reply?.level ?? SafetyLevel.general;
    final (Color accent, Color background, IconData icon) = switch (level) {
      SafetyLevel.general => (
        AppColors.ai,
        AppColors.surface,
        Icons.auto_awesome_rounded,
      ),
      SafetyLevel.caution => (
        AppColors.amber,
        AppColors.surface,
        Icons.info_rounded,
      ),
      SafetyLevel.urgent => (
        AppColors.danger,
        AppColors.dangerSoft,
        Icons.emergency_rounded,
      ),
    };
    final actionLabel = reply == null ? null : _destinationLabel(s, reply);
    final provenance = widget.message.provenance;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: const BorderRadiusDirectional.only(
                    topStart: Radius.circular(6),
                    topEnd: Radius.circular(20),
                    bottomStart: Radius.circular(20),
                    bottomEnd: Radius.circular(20),
                  ),
                  border: Border.all(
                    color: level == SafetyLevel.general
                        ? AppColors.border
                        : accent.withAlpha(70),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (level != SafetyLevel.general &&
                        reply != null &&
                        reply.title.trim().isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(icon, color: accent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reply.title,
                              style: text.titleMedium?.copyWith(color: accent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    SelectableText(
                      widget.message.text,
                      textDirection: directionOf(widget.message.text),
                      style: text.bodyLarge,
                    ),
                    if (level == SafetyLevel.urgent) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => callNumber(context, '997'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.danger,
                        ),
                        icon: const Icon(Icons.call_rounded),
                        label: Text(s.callAmbulance),
                      ),
                    ],
                    if (reply != null && reply.sources.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final source in reply.sources)
                            ActionChip(
                              avatar: const Icon(Icons.link_rounded, size: 16),
                              label: Text(
                                Uri.tryParse(source.url)?.host ?? source.title,
                                style: text.labelMedium,
                              ),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _showSources(context, reply),
                            ),
                        ],
                      ),
                    ],
                    if (reply?.suggestedPrompt?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 10),
                      InkWell(
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        onTap: () =>
                            widget.onUseSuggestion(reply.suggestedPrompt!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.aiSoft,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.subdirectory_arrow_right_rounded,
                                size: 18,
                                color: AppColors.ai,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  reply!.suggestedPrompt!,
                                  textDirection: directionOf(
                                    reply.suggestedPrompt!,
                                  ),
                                  style: text.bodyMedium?.copyWith(
                                    color: AppColors.ai,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_showDetails && reply?.contextNote != null) ...[
                      const SizedBox(height: 10),
                      Text(reply!.contextNote!, style: text.bodySmall),
                    ],
                    if (actionLabel != null) ...[
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: widget.onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: accent,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 40),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: Text(actionLabel),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 6, top: 4),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (provenance != null)
                      Text(
                        _provenanceLabel(s, provenance),
                        style: text.labelSmall,
                      ),
                    if (reply?.contextNote != null) ...[
                      if (provenance != null)
                        Text('  ·  ', style: text.labelSmall),
                      InkWell(
                        onTap: () =>
                            setState(() => _showDetails = !_showDetails),
                        child: Text(
                          s.details,
                          style: text.labelSmall?.copyWith(
                            color: AppColors.ai,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSources(BuildContext context, AssistantReply reply) {
    showAppSheet<void>(
      context: context,
      builder: (sheetContext) {
        final s = AppStrings.of(sheetContext);
        final text = Theme.of(sheetContext).textTheme;
        return SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: [
              SheetHeader(title: s.sources),
              const SizedBox(height: 12),
              for (final source in reply.sources)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SurfaceCard(
                    boxShadow: const [],
                    padding: const EdgeInsets.all(14),
                    onTap: () async {
                      final uri = Uri.tryParse(source.url);
                      if (uri == null) return;
                      try {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      } catch (_) {}
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(source.title, style: text.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          Uri.tryParse(source.url)?.host ?? source.url,
                          style: text.bodySmall?.copyWith(color: AppColors.ai),
                        ),
                        if (source.support.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(source.support, style: text.bodyMedium),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Opacity(
                    opacity: _dotOpacity(i),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.ai,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _dotOpacity(int index) {
    final phase = (_controller.value - index * .18) % 1;
    return .3 + .7 * (phase < .5 ? phase * 2 : (1 - phase) * 2);
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.voiceInput,
    required this.isThinking,
    required this.onSend,
    required this.onToggleVoice,
    required this.onCancelVoice,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoiceInputController voiceInput;
  final bool isThinking;
  final VoidCallback onSend;
  final VoidCallback onToggleVoice;
  final VoidCallback onCancelVoice;

  bool get _voiceBusy =>
      voiceInput.status == VoiceInputStatus.initializing ||
      voiceInput.status == VoiceInputStatus.finalizing;

  bool get _canSend =>
      !isThinking &&
      !voiceInput.isListening &&
      !_voiceBusy &&
      controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final simple = AppLayoutTokens.of(context).isSimple;

    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      minLines: 1,
      maxLines: simple ? 3 : 5,
      maxLength: AssistantRequestLimits.messageCharacters,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) {
        if (_canSend) onSend();
      },
      buildCounter:
          (context, {required currentLength, required isFocused, maxLength}) =>
              currentLength > (maxLength ?? 0) - 200
              ? Text('$currentLength/$maxLength')
              : null,
      decoration: InputDecoration(
        hintText: s.composerHint,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(26)),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(26)),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(26)),
          borderSide: BorderSide(color: AppColors.ai, width: 1.6),
        ),
      ),
    );

    final micIcon = _voiceBusy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(voiceInput.isListening ? Icons.stop_rounded : Icons.mic_rounded);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (voiceInput.isListening)
            _VoiceBanner(
              message: s.listening,
              listening: true,
              actionLabel: s.stop,
              onAction: onToggleVoice,
              onCancel: onCancelVoice,
              cancelTooltip: s.cancelVoice,
            )
          else if (voiceInput.errorMessage != null)
            _VoiceBanner(
              message: voiceInput.errorMessage!,
              listening: false,
              actionLabel: s.retry,
              onAction: onToggleVoice,
            ),
          if (simple) ...[
            field,
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _voiceBusy ? null : onToggleVoice,
                    icon: micIcon,
                    label: Text(voiceInput.isListening ? s.stop : s.speak),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _canSend ? onSend : null,
                    icon: const Icon(Icons.send_rounded),
                    label: Text(s.sendMessage),
                  ),
                ),
              ],
            ),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: IconButton(
                    tooltip: voiceInput.isListening ? s.stop : s.speak,
                    onPressed: _voiceBusy ? null : onToggleVoice,
                    style: IconButton.styleFrom(
                      backgroundColor: voiceInput.isListening
                          ? AppColors.dangerSoft
                          : AppColors.aiSoft,
                      foregroundColor: voiceInput.isListening
                          ? AppColors.danger
                          : AppColors.ai,
                      minimumSize: const Size.square(48),
                    ),
                    icon: micIcon,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: field),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: IconButton.filled(
                    tooltip: s.sendMessage,
                    onPressed: _canSend ? onSend : null,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.surfaceMuted,
                      minimumSize: const Size.square(48),
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _VoiceBanner extends StatelessWidget {
  const _VoiceBanner({
    required this.message,
    required this.listening,
    required this.actionLabel,
    required this.onAction,
    this.onCancel,
    this.cancelTooltip,
  });

  final String message;
  final bool listening;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback? onCancel;
  final String? cancelTooltip;

  @override
  Widget build(BuildContext context) {
    final color = listening ? AppColors.danger : AppColors.amber;
    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 4, 6),
        decoration: BoxDecoration(
          color: listening ? AppColors.dangerSoft : AppColors.amberSoft,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Row(
          children: [
            Icon(
              listening ? Icons.graphic_eq_rounded : Icons.info_outline_rounded,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: color),
              child: Text(actionLabel),
            ),
            if (onCancel != null)
              IconButton(
                tooltip: cancelTooltip,
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConsentSheet extends StatelessWidget {
  const _ConsentSheet();

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final text = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              leading: const PillAiMark(size: 48),
              title: s.consentTitle,
            ),
            const SizedBox(height: 18),
            _Bullet(icon: Icons.cloud_outlined, text: s.consentPoint1),
            _Bullet(
              icon: Icons.health_and_safety_outlined,
              text: s.consentPoint2,
            ),
            _Bullet(icon: Icons.toggle_on_outlined, text: s.consentPoint3),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.ai),
              child: Text(s.consentAgree),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(foregroundColor: AppColors.inkMuted),
              child: Text(s.consentOffline, style: text.labelLarge),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceNoticeSheet extends StatelessWidget {
  const _VoiceNoticeSheet();

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              leading: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.aiSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic_rounded, color: AppColors.ai),
              ),
              title: s.voiceTitle,
            ),
            const SizedBox(height: 14),
            Text(s.voiceBody, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.ai),
              child: Text(s.continueLabel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.notNow),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutSheet extends StatelessWidget {
  const _AboutSheet({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              leading: const PillAiMark(size: 44),
              title: s.howPillAiKeepsYouSafe,
            ),
            const SizedBox(height: 16),
            for (final promise in s.safetyPromises)
              _Bullet(icon: Icons.check_circle_outline_rounded, text: promise),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: store,
              builder: (context, _) => SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: store.remoteAiConsent == true,
                title: Text(s.smartAnswers),
                onChanged: (value) => store.setRemoteAiConsent(value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
