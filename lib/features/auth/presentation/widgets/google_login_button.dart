import 'package:flutter/material.dart';

import 'google_login_button_stub.dart'
    if (dart.library.html) 'google_login_button_web.dart'
    as platform;

Widget buildGoogleLoginButton({required VoidCallback onPressed}) =>
    platform.buildGoogleLoginButton(onPressed: onPressed);
