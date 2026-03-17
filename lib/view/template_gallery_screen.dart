import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:serva/api/go_models.dart';
import 'package:serva/bloc/main_bloc.dart';
import 'package:serva/bloc/main_event.dart';
import 'package:serva/bloc/main_state.dart';
import 'package:url_launcher/url_launcher.dart';

part 'launch/template_gallery_catalog.dart';
part 'launch/template_gallery_models.dart';
part 'launch/template_gallery_support.dart';
part 'launch/template_gallery_helpers.dart';
part 'launch/template_gallery_sections.dart';
part 'launch/template_gallery_tile.dart';
part 'launch/template_gallery_actions.dart';
part 'launch/template_gallery_dialogs.dart';
part 'launch/template_gallery_persistence.dart';

class TemplateGalleryScreen extends StatefulWidget {
  const TemplateGalleryScreen({super.key});

  static final ValueNotifier<List<_TemplateCardModel>> customTemplates =
      ValueNotifier<List<_TemplateCardModel>>(<_TemplateCardModel>[]);
  static final ValueNotifier<Set<String>> verifiedTemplateKeys =
      ValueNotifier<Set<String>>(<String>{});

  static void resetLocalTemplateState() {
    customTemplates.value = <_TemplateCardModel>[];
    verifiedTemplateKeys.value = _defaultVerifiedTemplateKeys();
  }

  static const templates = _templateCatalog;

  @override
  State<TemplateGalleryScreen> createState() => _TemplateGalleryScreenState();
}

class _TemplateGalleryScreenState extends State<TemplateGalleryScreen> {
  @override
  void initState() {
    super.initState();
    _loadPersistedVerifiedTemplates();
    _loadPersistedCustomTemplates();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final mutedText = textColor.withValues(alpha: 0.74);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surface,
            Color.alphaBlend(
              theme.colorScheme.primary.withValues(alpha: 0.08),
              theme.colorScheme.surfaceContainerLowest,
            ),
          ],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          Text(
            'One-Click Launch',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a service tile and Serva will create it with a ready-made image, port, and persistent data layout.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: mutedText,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _openInfiniteTemplates(context),
                icon: const Icon(Icons.travel_explore_rounded, size: 18),
                label: const Text('Browse Online'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _pasteImageOrCommand(context),
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                label: const Text('Paste Image'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _LaunchCallout(textColor: textColor),
          const SizedBox(height: 10),
          ValueListenableBuilder<Set<String>>(
            valueListenable: TemplateGalleryScreen.verifiedTemplateKeys,
            builder: (context, verifiedKeys, _) {
              final builtInExperimental = TemplateGalleryScreen.templates
                  .where((template) => !verifiedKeys.contains(_templateKey(template)))
                  .toList();

              return ValueListenableBuilder<List<_TemplateCardModel>>(
                valueListenable: TemplateGalleryScreen.customTemplates,
                builder: (context, customTemplatesValue, _) {
                  final verifiedBuiltIns = TemplateGalleryScreen.templates
                      .where((template) => verifiedKeys.contains(_templateKey(template)))
                      .toList();
                  final verifiedCustom = customTemplatesValue
                      .where((template) => verifiedKeys.contains(_templateKey(template)))
                      .toList();
                  final experimentalCustom = customTemplatesValue
                      .where((template) => !verifiedKeys.contains(_templateKey(template)))
                      .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TemplateSection(
                        title: 'Verified',
                        subtitle: 'Templates we have personally smoke-tested.',
                        templates: [...verifiedBuiltIns, ...verifiedCustom],
                      ),
                      const SizedBox(height: 10),
                      _TemplateSection(
                        title: 'Experimental',
                        subtitle: 'Everything else, including pasted images and unverified presets.',
                        templates: [...experimentalCustom, ...builtInExperimental],
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
