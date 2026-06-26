abstract final class FfmpegCommand {
  static List<String> imagesToGif({
    required String concatFilePath,
    required String outputPath,
    int? width,
  }) {
    final scale = width != null ? 'scale=$width:-1:flags=lanczos,' : '';
    return [
      '-y',
      '-f', 'concat', '-safe', '0',
      '-i', concatFilePath,
      '-filter_complex',
      '${scale}split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5',
      '-loop', '0',
      '-progress', 'pipe:1',
      outputPath,
    ];
  }

  static List<String> videoToGif({
    required String inputPath,
    required String outputPath,
    int fps = 15,
    int? width,
    Duration? start,
    Duration? duration,
  }) {
    final args = <String>['-y'];
    if (start != null) {
      args.addAll(['-ss', (start.inMilliseconds / 1000).toStringAsFixed(3)]);
    }
    if (duration != null) {
      args.addAll(['-t', (duration.inMilliseconds / 1000).toStringAsFixed(3)]);
    }
    args.add('-i');
    args.add(inputPath);
    final scale = width != null ? 'scale=$width:-1:flags=lanczos,' : '';
    args.addAll([
      '-filter_complex',
      '[0:v] fps=$fps,${scale}split [a][b];[a] palettegen=stats_mode=diff [p];[b][p] paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle',
      '-loop', '0',
      '-progress', 'pipe:1',
      outputPath,
    ]);
    return args;
  }

  static List<String> resize({
    required String inputPath,
    required String outputPath,
    int? width,
    int? height,
  }) {
    final w = width?.toString() ?? '-1';
    final h = height?.toString() ?? '-1';
    return [
      '-y', '-i', inputPath,
      '-filter_complex',
      'scale=$w:$h:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse',
      '-loop', '0',
      '-progress', 'pipe:1',
      outputPath,
    ];
  }

  static List<String> cropGif({
    required String inputPath,
    required String outputPath,
    required int x,
    required int y,
    required int cropWidth,
    required int cropHeight,
  }) {
    return [
      '-y', '-i', inputPath,
      '-filter_complex',
      'crop=$cropWidth:$cropHeight:$x:$y,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5',
      '-loop', '0',
      '-progress', 'pipe:1',
      outputPath,
    ];
  }

  static List<String> optimizeGifFfmpeg({
    required String inputPath,
    required String outputPath,
    int colors = 128,
  }) {
    return [
      '-y', '-i', inputPath,
      '-filter_complex',
      'split[a][b];[a]palettegen=max_colors=$colors:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5',
      '-loop', '0',
      '-progress', 'pipe:1',
      outputPath,
    ];
  }

  static List<String> textOverlay({
    required String inputPath,
    required String outputPath,
    required String text,
    required String fontFile,
    int fontSize = 36,
    String fontColor = 'white',
    String position = 'center',
  }) {
    final escapedText = text
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll(':', r'\:');
    final escapedFont = _escapeFontPath(fontFile);
    final (x, y) = _textPosition(position, fontSize);
    return [
      '-y', '-i', inputPath,
      '-filter_complex',
      "drawtext=fontfile='$escapedFont':text='$escapedText':x=$x:y=$y:fontsize=$fontSize:fontcolor=$fontColor:borderw=2:bordercolor=black@0.6,split[a][b];[a]palettegen[p];[b][p]paletteuse",
      '-loop', '0',
      '-progress', 'pipe:1',
      outputPath,
    ];
  }

  static String _escapeFontPath(String path) {
    // Convert backslashes to forward slashes, escape Windows drive colon
    var p = path.replaceAll(r'\', '/');
    p = p.replaceAllMapped(RegExp(r'^([A-Za-z]):/'), (m) => '${m[1]}\\:/');
    return p;
  }

  static (String, String) _textPosition(String position, int fontSize) =>
      switch (position) {
        'top'    => ('(w-text_w)/2', '$fontSize'),
        'bottom' => ('(w-text_w)/2', 'h-text_h-$fontSize'),
        _        => ('(w-text_w)/2', '(h-text_h)/2'),
      };

  static List<String> reverseGif({
    required String inputPath,
    required String outputPath,
  }) {
    return [
      '-y', '-i', inputPath,
      '-filter_complex',
      'reverse,split[a][b];[a]palettegen[p];[b][p]paletteuse',
      '-loop', '0',
      '-progress', 'pipe:1',
      outputPath,
    ];
  }

  static List<String> changeSpeed({
    required String inputPath,
    required String outputPath,
    required double factor,
  }) {
    final pts = (1.0 / factor).toStringAsFixed(6);
    return [
      '-y', '-i', inputPath,
      '-filter_complex',
      'setpts=$pts*PTS,split[a][b];[a]palettegen[p];[b][p]paletteuse',
      '-loop', '0',
      '-progress', 'pipe:1',
      outputPath,
    ];
  }

  /// Builds a concat demuxer file listing [framePaths] at [fps].
  static String buildConcatFileContent(List<String> framePaths, int fps) {
    final duration = (1.0 / fps).toStringAsFixed(6);
    final buf = StringBuffer();
    for (final p in framePaths) {
      final escaped = p.replaceAll('\\', '/').replaceAll("'", r"\'");
      buf.writeln("file '$escaped'");
      buf.writeln('duration $duration');
    }
    return buf.toString();
  }
}
