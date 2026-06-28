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

  static String _escapeText(String text) => text
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(':', r'\:');

  static List<String> textOverlay({
    required String inputPath,
    required String outputPath,
    required String text,
    required String fontFile,
    int fontSize = 36,
    String fontColor = 'white',
    String position = 'center',
  }) {
    final escapedText = _escapeText(text);
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

  static List<String> videoEdit({
    required String inputPath,
    required String outputPath,
    int? cropX,
    int? cropY,
    int? cropW,
    int? cropH,
    int? scaleW,
    int? scaleH,
    double speedFactor = 1.0,
    required String encoder,
    bool hasAudio = false,
    int? startMs,
    int? durationMs,
    String? drawText,
    String? drawTextFont,
    int drawTextSize = 36,
    String drawTextColor = 'white',
    String drawTextPosition = 'center',
  }) {
    final vf = <String>[];

    if (cropX != null && cropY != null && cropW != null && cropH != null) {
      vf.add('crop=$cropW:$cropH:$cropX:$cropY');
    }

    if (scaleW != null) {
      final w = (scaleW ~/ 2) * 2;
      if (scaleH != null) {
        final h = (scaleH ~/ 2) * 2;
        vf.add('scale=$w:$h:flags=lanczos');
      } else {
        vf.add('scale=$w:-2:flags=lanczos');
      }
    } else {
      vf.add('scale=trunc(iw/2)*2:trunc(ih/2)*2');
    }

    final speedChanged = (speedFactor - 1.0).abs() > 0.001;
    if (speedChanged) {
      final pts = (1.0 / speedFactor).toStringAsFixed(6);
      vf.add('setpts=$pts*PTS');
    }

    if (drawText != null && drawText.isNotEmpty && drawTextFont != null) {
      final (x, y) = _textPosition(drawTextPosition, drawTextSize);
      final escaped = _escapeText(drawText);
      final escapedFont = _escapeFontPath(drawTextFont);
      vf.add("drawtext=fontfile='$escapedFont':text='$escaped':x=$x:y=$y:fontsize=$drawTextSize:fontcolor=$drawTextColor:borderw=2:bordercolor=black@0.6");
    }

    final args = ['-y'];
    if (startMs != null && startMs > 0) {
      args.addAll(['-ss', (startMs / 1000).toStringAsFixed(3)]);
    }
    args.addAll(['-i', inputPath]);
    if (durationMs != null && durationMs > 0) {
      args.addAll(['-t', (durationMs / 1000).toStringAsFixed(3)]);
    }
    args.addAll(['-vf', vf.join(',')]);

    if (hasAudio) {
      if (speedChanged) args.addAll(['-af', _atempoChain(speedFactor)]);
      args.addAll(['-c:a', 'aac', '-b:a', '160k']);
    } else {
      args.add('-an');
    }

    args.addAll(_encoderArgs(encoder));
    args.addAll(['-progress', 'pipe:1', outputPath]);
    return args;
  }

  static List<String> videoStreamCopy({
    required String inputPath,
    required String outputPath,
  }) =>
      ['-y', '-i', inputPath, '-c', 'copy', outputPath];

  /// Bakes the video layers (crop · resize · speed · trim · text) into a GIF in one pass.
  /// crop → fps → scale → setpts → drawtext → palettegen/paletteuse.
  static List<String> videoEditToGif({
    required String inputPath,
    required String outputPath,
    int? cropX,
    int? cropY,
    int? cropW,
    int? cropH,
    int? scaleW,
    double speedFactor = 1.0,
    int fps = 15,
    int? startMs,
    int? durationMs,
    String? drawText,
    String? drawTextFont,
    int drawTextSize = 36,
    String drawTextColor = 'white',
    String drawTextPosition = 'center',
  }) {
    final pre = <String>[];
    if (cropX != null && cropY != null && cropW != null && cropH != null) {
      pre.add('crop=$cropW:$cropH:$cropX:$cropY');
    }
    pre.add('fps=$fps');
    if (scaleW != null) pre.add('scale=$scaleW:-1:flags=lanczos');
    if ((speedFactor - 1.0).abs() > 0.001) {
      pre.add('setpts=${(1.0 / speedFactor).toStringAsFixed(6)}*PTS');
    }
    if (drawText != null && drawText.isNotEmpty && drawTextFont != null) {
      final (x, y) = _textPosition(drawTextPosition, drawTextSize);
      final escaped = _escapeText(drawText);
      final escapedFont = _escapeFontPath(drawTextFont);
      pre.add("drawtext=fontfile='$escapedFont':text='$escaped':x=$x:y=$y:fontsize=$drawTextSize:fontcolor=$drawTextColor:borderw=2:bordercolor=black@0.6");
    }
    final args = ['-y'];
    if (startMs != null && startMs > 0) {
      args.addAll(['-ss', (startMs / 1000).toStringAsFixed(3)]);
    }
    args.addAll(['-i', inputPath]);
    if (durationMs != null && durationMs > 0) {
      args.addAll(['-t', (durationMs / 1000).toStringAsFixed(3)]);
    }
    args.addAll([
      '-filter_complex',
      '[0:v] ${pre.join(',')},split [a][b];[a] palettegen=stats_mode=diff [p];[b][p] paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle',
      '-loop', '0',
      '-progress', 'pipe:1',
      outputPath,
    ]);
    return args;
  }

  /// Applies crop · resize · speed · text to an existing GIF in one pass.
  /// Caller must guard the no-op case (copy instead of re-encode).
  static List<String> gifEdit({
    required String inputPath,
    required String outputPath,
    int? cropX,
    int? cropY,
    int? cropW,
    int? cropH,
    int? scaleW,
    double speedFactor = 1.0,
    String? drawText,
    String? drawTextFont,
    int drawTextSize = 36,
    String drawTextColor = 'white',
    String drawTextPosition = 'center',
    int? fps,
    int loopCount = 0,
    bool boomerang = false,
  }) {
    final pre = <String>[];
    if (cropX != null && cropY != null && cropW != null && cropH != null) {
      pre.add('crop=$cropW:$cropH:$cropX:$cropY');
    }
    if (fps != null) pre.add('fps=$fps');
    if (scaleW != null) pre.add('scale=$scaleW:-1:flags=lanczos');
    if ((speedFactor - 1.0).abs() > 0.001) {
      pre.add('setpts=${(1.0 / speedFactor).toStringAsFixed(6)}*PTS');
    }
    if (drawText != null && drawText.isNotEmpty && drawTextFont != null) {
      final (x, y) = _textPosition(drawTextPosition, drawTextSize);
      final escaped = _escapeText(drawText);
      final escapedFont = _escapeFontPath(drawTextFont);
      pre.add("drawtext=fontfile='$escapedFont':text='$escaped':x=$x:y=$y:fontsize=$drawTextSize:fontcolor=$drawTextColor:borderw=2:bordercolor=black@0.6");
    }
    final chain = pre.isEmpty ? 'null' : pre.join(',');
    // Boomerang: append a reversed copy of the (edited) stream so the GIF plays
    // forward then backward → seamless ping-pong loop.
    final body = boomerang
        ? '$chain,split[fwd][r0];[r0]reverse[rev];[fwd][rev]concat=n=2:v=1,split[a][b]'
        : '$chain,split[a][b]';
    return [
      '-y', '-i', inputPath,
      '-filter_complex',
      '$body;[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5',
      '-loop', '$loopCount',
      '-progress', 'pipe:1',
      outputPath,
    ];
  }

  static String _atempoChain(double factor) {
    final filters = <String>[];
    var f = factor;
    while (f > 2.0) {
      filters.add('atempo=2.0');
      f /= 2.0;
    }
    while (f < 0.5) {
      filters.add('atempo=0.5');
      f /= 0.5;
    }
    filters.add('atempo=${f.toStringAsFixed(4)}');
    return filters.join(',');
  }

  static List<String> _encoderArgs(String encoder) => switch (encoder) {
    'h264_nvenc'       => ['-c:v', 'h264_nvenc', '-cq', '23'],
    'h264_qsv'        => ['-c:v', 'h264_qsv', '-global_quality', '23'],
    'h264_amf'        => ['-c:v', 'h264_amf', '-qp_i', '23', '-qp_p', '23'],
    'h264_mediacodec' => ['-c:v', 'h264_mediacodec', '-b:v', '4M'],
    _                 => ['-c:v', 'libx264', '-preset', 'fast', '-crf', '20'],
  };

  /// Builds a concat demuxer file listing [framePaths] at [fps].
  static String buildConcatFileContent(List<String> framePaths, int fps) {
    final duration = (1.0 / fps).toStringAsFixed(6);
    final buf = StringBuffer();
    for (final p in framePaths) {
      final escaped = p.replaceAll('\\', '/').replaceAll("'", r"\'");
      buf.writeln("file '$escaped'");
      buf.writeln('duration $duration');
    }
    // Repeat last frame without duration so concat demuxer honors its duration
    if (framePaths.isNotEmpty) {
      final lastEscaped =
          framePaths.last.replaceAll('\\', '/').replaceAll("'", r"\'");
      buf.writeln("file '$lastEscaped'");
    }
    return buf.toString();
  }
}
