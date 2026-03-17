import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:serva/api/go_models.dart';
import 'package:serva/api/sovereign_api.dart';
import 'package:serva/bloc/main_bloc.dart';
import 'package:serva/bloc/main_event.dart';
import 'package:serva/bloc/main_state.dart';
import 'package:url_launcher/url_launcher.dart';

import 'service_details_sheet.dart';
import 'template_gallery_screen.dart';

part 'services/services_overview_shell.dart';
part 'services/services_overview_metrics.dart';
part 'services/services_overview_storage.dart';
part 'services/services_overview_panels.dart';
part 'services/services_active_tile.dart';
part 'services/services_inactive_tile.dart';
part 'services/services_data_panel.dart';
part 'services/services_data_tile.dart';
part 'services/services_data_tile_ops.dart';
part 'services/services_shared_widgets.dart';
part 'services/services_models.dart';
