import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:serva/api/go_models.dart';
import 'package:serva/api/sovereign_api.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bloc/main_bloc.dart';
import '../bloc/main_event.dart';
import '../bloc/main_state.dart';
import 'dashboard_screen.dart';
import 'service_details_sheet.dart';
import 'services_overview_screen.dart';
import 'template_gallery_screen.dart';

part 'home/home_utils.dart';
part 'home/home_shell.dart';
part 'home/home_feedback_views.dart';
part 'home/home_legacy_content.dart';
part 'home/home_legacy_tiles.dart';
part 'home/home_detail_shared.dart';
part 'home/home_service_detail_sections.dart';
part 'home/home_service_detail_sheet.dart';
part 'home/home_definition_detail_sheet.dart';
part 'home/home_create_service_templates.dart';
part 'home/home_create_service_sections.dart';
part 'home/home_create_service_logic.dart';
part 'home/home_create_service_sheet.dart';
