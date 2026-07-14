import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../llm/llm_providers.dart';
import '../models/knowledge_item.dart';
import '../providers/knowledge_providers.dart';
import 'widgets/image_picking.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final _formKey = GlobalKey<FormState>();
  final _frontController = TextEditingController();
  final _backController = TextEditingController();
  final _categoryController = TextEditingController();
  KnowledgeType _type = KnowledgeType.concept;
  bool _saving = false;
  bool _aiBusy = false;
  Uint8List? _imageBytes;
  // Pre-generated multiple-choice quiz, cached when the answer is AI-generated.
  String? _mcAnswer;
  List<String> _mcDistractors = const [];

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _expandWithAi() async {
    final llm = ref.read(llmProvider);
    if (llm == null) return;
    final front = _frontController.text.trim();
    if (front.isEmpty) return;
    setState(() => _aiBusy = true);
    try {
      final now = DateTime.now();
      final probe = KnowledgeItem(
        id: '',
        front: front,
        back: _backController.text.trim().isEmpty ? null : _backController.text.trim(),
        type: _type,
        createdAt: now,
        dueDate: now,
      );
      // Fill the detailed answer, then pre-build a concise MC quiz to cache.
      final answer = await llm.expandNote(probe);
      if (mounted) _backController.text = answer;
      try {
        final quiz = await llm.generateQuiz(probe.copyWith(back: answer));
        _mcAnswer = quiz.answer;
        _mcDistractors = quiz.distractors;
      } catch (_) {
        // Non-fatal: MC options will be generated lazily during practice.
      }
    } catch (e) {
      _showError('Could not generate: $e');
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _suggestCategory() async {
    final llm = ref.read(llmProvider);
    if (llm == null) return;
    final front = _frontController.text.trim();
    if (front.isEmpty) return;
    setState(() => _aiBusy = true);
    try {
      final cat = await llm.suggestCategory(
        front,
        _backController.text.trim().isEmpty ? null : _backController.text.trim(),
      );
      if (mounted) _categoryController.text = cat;
    } catch (e) {
      _showError('Could not suggest: $e');
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await ref.read(knowledgeListProvider.notifier).addItem(
          front: _frontController.text,
          back: _backController.text,
          type: _type,
          category: _categoryController.text,
          imageBytes: _imageBytes,
          mcAnswer: _mcAnswer,
          mcDistractors: _mcDistractors,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickImage() async {
    final bytes = await pickImageBytes(context);
    if (bytes != null && mounted) setState(() => _imageBytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final aiAttached = ref.watch(llmProvider) != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Capture knowledge')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('What kind of thing is this?',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final type in KnowledgeType.values)
                  ChoiceChip(
                    label: Text(type.label),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _frontController,
              autofocus: true,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Prompt',
                hintText:
                    'A question, a concept name, a command — what to recall',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Add something to recall' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _backController,
              minLines: 2,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Answer / details (optional)',
                hintText: 'Leave blank if you only jotted a fragment',
                border: OutlineInputBorder(),
              ),
            ),
            if (aiAttached) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _aiBusy ? null : _expandWithAi,
                  icon: _aiBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Generate answer'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Category (optional)',
                      hintText: 'e.g. Math, ML, Linux, Cybersec',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                if (aiAttached)
                  IconButton(
                    tooltip: 'Suggest category',
                    onPressed: _aiBusy ? null : _suggestCategory,
                    icon: const Icon(Icons.auto_awesome),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_imageBytes != null) ...[
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _imageBytes!,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _imageBytes = null),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: Text(_imageBytes == null ? 'Add image' : 'Replace image'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
