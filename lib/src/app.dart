import 'package:flutter/material.dart';

import 'editor/editor_page.dart';

class WebUiCanvasApp extends StatelessWidget {
  const WebUiCanvasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Web UI Canvas',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff4f5b66)),
      ),
      home: const EditorPage(),
    );
  }
}
