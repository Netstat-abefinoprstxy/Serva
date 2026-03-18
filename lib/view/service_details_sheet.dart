import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:serva/api/go_models.dart';
import 'package:serva/api/sovereign_api.dart';
import 'package:serva/bloc/main_bloc.dart';
import 'package:serva/bloc/main_event.dart';
import 'package:serva/tailscale_auth.dart';
import 'package:url_launcher/url_launcher.dart';

part 'service_details/service_details_shell.dart';
part 'service_details/service_details_sections.dart';
part 'service_details/service_details_shared.dart';
