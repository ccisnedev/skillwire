// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/server.dart';
import 'package:design_system/src/command.dart' as _command;
import 'package:design_system/src/diagram.dart' as _diagram;
import 'package:design_system/src/layout.dart' as _layout;
import 'package:design_system/src/masthead.dart' as _masthead;
import 'package:design_system/src/rows.dart' as _rows;
import 'package:design_system/src/terminal.dart' as _terminal;
import 'package:skillwire_site/sections/colophon.dart' as _colophon;
import 'package:skillwire_site/sections/embedding.dart' as _embedding;
import 'package:skillwire_site/sections/install.dart' as _install;
import 'package:skillwire_site/sections/provenance.dart' as _provenance;
import 'package:skillwire_site/sections/rules.dart' as _rules;
import 'package:skillwire_site/app.dart' as _app;

/// Default [ServerOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.server.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultServerOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ServerOptions get defaultServerOptions => ServerOptions(
  styles: () => [
    ..._command.Command.styles,
    ..._diagram.Diagram.styles,
    ..._layout.Band.styles,
    ..._layout.Listing.styles,
    ..._layout.Page.styles,
    ..._masthead.Masthead.styles,
    ..._rows.Rows.styles,
    ..._terminal.Terminal.styles,
    ..._app.App.styles,
    ..._colophon.Colophon.styles,
    ..._embedding.Embedding.styles,
    ..._install.Install.styles,
    ..._provenance.Provenance.styles,
    ..._rules.Rules.styles,
  ],
);
