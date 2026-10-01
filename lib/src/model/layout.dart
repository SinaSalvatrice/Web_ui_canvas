enum WebLayoutMode {
  free('Free'),
  row('Row'),
  column('Column'),
  grid('Grid'),
  flow('Flow');

  const WebLayoutMode(this.label);
  final String label;
}

enum WebMainAlignment {
  start('Start'),
  center('Center'),
  end('End'),
  spaceBetween('Space between');

  const WebMainAlignment(this.label);
  final String label;
}

enum WebCrossAlignment {
  start('Start'),
  center('Center'),
  end('End'),
  stretch('Stretch');

  const WebCrossAlignment(this.label);
  final String label;
}
