import 'dart:io' show Platform;

/// A span (absolute source ms) marked for removal from the output. start < end.
typedef CutSegment = ({int startMs, int endMs});

class DrawTextSpec {
  const DrawTextSpec({
    required this.text,
    required this.fontFile,
    required this.x,
    required this.y,
    required this.fontSize,
    required this.fontColorHex,
    required this.strokeColorHex,
    required this.strokeWidth,
  });

  final String text;
  final String fontFile;
  final int x;
  final int y;
  final int fontSize;
  final String fontColorHex; // RRGGBB
  final String strokeColorHex; // RRGGBB
  final int strokeWidth; // 0 = none
}

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

  // drawtext text is wrapped in filtergraph single quotes by every caller.
  // Inside '...', ffmpeg treats backslash as literal, so a `'` cannot be
  // backslash-escaped — it must close the quote, emit an escaped quote, and
  // reopen: ' -> '\''. (`\'` instead leaves the quote open and the rest of the
  // filtergraph, including the trailing ,split, gets swallowed → EINVAL.)
  // `%` is escaped so drawtext does not treat it as a `%{...}` expansion.
  static String _escapeText(String text) => text
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll(':', r'\:')
      .replaceAll("'", "'\\''");

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

  /// Builds one drawtext filter segment for [s] (absolute px position, per-item
  /// color + stroke). Shared by the GIF [textOverlayMulti] bake and the video
  /// [videoEdit] bake so escaping/quoting lives in one place.
  static String _sanitizeHex(String hex) =>
      RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex) ? hex : 'FFFFFF';

  static String _drawTextPart(DrawTextSpec s) {
    final t = _escapeText(s.text);
    final f = _escapeFontPath(s.fontFile);
    final fc = _sanitizeHex(s.fontColorHex);
    final sc = _sanitizeHex(s.strokeColorHex);
    final stroke = s.strokeWidth > 0
        ? ':borderw=${s.strokeWidth}:bordercolor=0x$sc'
        : ':borderw=0';
    return "drawtext=fontfile='$f':text='$t':x=${s.x}:y=${s.y}:fontsize=${s.fontSize}:fontcolor=0x$fc$stroke";
  }

  static List<String> textOverlayMulti({
    required String inputPath,
    required String outputPath,
    required List<DrawTextSpec> specs,
  }) {
    assert(specs.isNotEmpty, 'textOverlayMulti requires at least one DrawTextSpec');
    final parts = specs.map(_drawTextPart).join(',');
    return [
      '-y', '-i', inputPath,
      '-filter_complex',
      '$parts,split[a][b];[a]palettegen[p];[b][p]paletteuse',
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

  /// Builds the `between(t,s,e)+...` expression used by select/aselect filters.
  static String _selectKeepExpr(List<CutSegment> ranges) {
    return ranges.map((r) {
      final s = (r.startMs / 1000).toStringAsFixed(3);
      final e = (r.endMs / 1000).toStringAsFixed(3);
      return 'between(t,$s,$e)';
    }).join('+');
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
    String? encoder, // h264 candidate; required unless webm is true
    bool hasAudio = false,
    double volume = 1.0,
    int? startMs,
    int? durationMs,
    List<DrawTextSpec>? textSpecs,
    String? drawText,
    String? drawTextFont,
    int drawTextSize = 36,
    String drawTextColor = 'white',
    String drawTextPosition = 'center',
    List<CutSegment>? keepRanges,
    // Loop crossfade (video stage): dissolves the tail into the head so
    // export loops seamlessly — same idea as gifEdit's smoothLoop, extended
    // to also crossfade audio (acrossfade) when the source has a track.
    // [loopDurationMs] is the pre-speed effective window (post trim/cut,
    // matching what [startMs]/[durationMs]/[keepRanges] already select) —
    // required so the graph knows where head/tail/mid land.
    bool smoothLoop = false,
    int crossfadeMs = 1000,
    int? loopDurationMs,
    // WebM export (§8 of PLAN.md) — same filter graph, VP9 encoder block
    // (shared with toWebm) instead of h264, Opus instead of AAC.
    bool webm = false,
    int webmCrf = 32,
    int webmCpuUsed = 4,
    int webmThreads = 0,
  }) {
    assert(webm || encoder != null, 'encoder required when webm is false');
    if (smoothLoop && (loopDurationMs == null || loopDurationMs <= 0)) {
      throw ArgumentError('smoothLoop requires a positive loopDurationMs');
    }
    final hasCut = keepRanges != null && keepRanges.isNotEmpty;
    final vf = <String>[];

    // When cuts present: select/setpts owns the window (no -ss/-t).
    if (hasCut) {
      final expr = _selectKeepExpr(keepRanges);
      vf.add("select='$expr',setpts=N/FRAME_RATE/TB");
    }

    // Multi-item text (specs carry source-px positions) bakes first, before
    // crop/scale, so the texted frames transform with the content — matching
    // the GIF text pipeline and the live preview (text positioned over the
    // full source frame).
    if (textSpecs != null && textSpecs.isNotEmpty) {
      vf.addAll(textSpecs.map(_drawTextPart));
    }

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

    final af = <String>[];
    if (hasAudio) {
      // When cuts present: aselect/asetpts must come first in the audio chain.
      if (hasCut) {
        final expr = _selectKeepExpr(keepRanges);
        af.add("aselect='$expr',asetpts=N/SR/TB");
      }
      if (speedChanged) af.add(_atempoChain(speedFactor));
      if ((volume - 1.0).abs() > 0.001) {
        af.add('volume=${volume.toStringAsFixed(3)}');
      }
    }

    final args = ['-y'];
    if (!hasCut && startMs != null && startMs > 0) {
      args.addAll(['-ss', (startMs / 1000).toStringAsFixed(3)]);
    }
    args.addAll(['-i', inputPath]);
    if (!hasCut && durationMs != null && durationMs > 0) {
      args.addAll(['-t', (durationMs / 1000).toStringAsFixed(3)]);
    }

    if (smoothLoop) {
      final cf = crossfadeMs / 1000;
      final d = (loopDurationMs! / 1000) / speedFactor;
      if (d <= 2 * cf + 0.1) {
        throw ArgumentError(
            'smoothLoop: post-speed duration ${d}s too short for a ${cf}s crossfade');
      }
      String f(double v) => v.toStringAsFixed(3);
      final vchain = vf.join(',');
      var filterComplex = '[0:v]$vchain,split=3[vp0][vp1][vp2];'
          '[vp0]trim=0:${f(cf)},setpts=PTS-STARTPTS[vhead];'
          '[vp1]trim=${f(d - cf)}:${f(d)},setpts=PTS-STARTPTS[vtail];'
          '[vp2]trim=${f(cf)}:${f(d - cf)},setpts=PTS-STARTPTS[vmid];'
          '[vtail][vhead]xfade=transition=fade:duration=${f(cf)}:offset=0[vblend];'
          '[vmid][vblend]concat=n=2:v=1:a=0[vout]';
      if (hasAudio) {
        final achain = af.isEmpty ? 'anull' : af.join(',');
        filterComplex += ';[0:a]$achain,asplit=3[ap0][ap1][ap2];'
            '[ap0]atrim=0:${f(cf)},asetpts=PTS-STARTPTS[ahead];'
            '[ap1]atrim=${f(d - cf)}:${f(d)},asetpts=PTS-STARTPTS[atail];'
            '[ap2]atrim=${f(cf)}:${f(d - cf)},asetpts=PTS-STARTPTS[amid];'
            '[atail][ahead]acrossfade=d=${f(cf)}:c1=tri:c2=tri[ablend];'
            '[amid][ablend]concat=n=2:v=0:a=1[aout]';
      }
      args.addAll(['-filter_complex', filterComplex, '-map', '[vout]']);
      // split/trim/xfade/concat leaves the negotiated pix_fmt to the filter
      // graph, which can land on yuv444p (High 4:4:4 Predictive) instead of
      // the source's yuv420p — many hardware decoders/players can't handle
      // that profile and render black. Force it explicitly (the non-
      // smoothLoop -vf path never triggers this: simple filters keep the
      // source format, only this split/concat graph renegotiates it).
      args.addAll(['-pix_fmt', 'yuv420p']);
      if (hasAudio) {
        args.addAll(['-map', '[aout]']);
        args.addAll(webm
            ? ['-c:a', 'libopus', '-b:a', '128k']
            : ['-c:a', 'aac', '-b:a', '160k']);
      } else {
        args.add('-an');
      }
    } else {
      args.addAll(['-vf', vf.join(',')]);
      if (webm) args.addAll(['-pix_fmt', 'yuv420p']);
      if (hasAudio) {
        if (af.isNotEmpty) args.addAll(['-af', af.join(',')]);
        args.addAll(webm
            ? ['-c:a', 'libopus', '-b:a', '128k']
            : ['-c:a', 'aac', '-b:a', '160k']);
      } else {
        args.add('-an');
      }
    }

    args.addAll(webm
        ? _webmEncoderArgs(
            crf: webmCrf, cpuUsed: webmCpuUsed, av1: false, threads: webmThreads)
        : _encoderArgs(encoder!));
    args.addAll(['-progress', 'pipe:1', outputPath]);
    return args;
  }

  static List<String> videoStreamCopy({
    required String inputPath,
    required String outputPath,
  }) =>
      ['-y', '-i', inputPath, '-c', 'copy', outputPath];

  /// Bakes the video layers (crop · resize · speed · trim · cut) into a GIF in
  /// two passes sharing one filter chain: the palette pass writes palettegen's
  /// output to [palettePath], the render pass maps frames through it. Two
  /// passes decode the window twice but stream frame-by-frame — the one-pass
  /// split/palettegen graph FIFO-buffers every frame in RAM until EOF (~2.7 GB
  /// for 40 s of HD), which dwarfs the second decode.
  /// When keepRanges present: select/setpts first (before crop/fps).
  /// Otherwise: crop → fps → scale → setpts.
  static ({List<String> palettePass, List<String> renderPass}) videoEditToGif({
    required String inputPath,
    required String outputPath,
    required String palettePath,
    int? cropX,
    int? cropY,
    int? cropW,
    int? cropH,
    int? scaleW,
    double speedFactor = 1.0,
    int fps = 15,
    int? startMs,
    int? durationMs,
    List<CutSegment>? keepRanges,
  }) {
    final hasCut = keepRanges != null && keepRanges.isNotEmpty;
    final pre = <String>[];
    // When cuts present: select/setpts must come first (before crop/fps).
    if (hasCut) {
      final expr = _selectKeepExpr(keepRanges);
      pre.add("select='$expr',setpts=N/FRAME_RATE/TB");
    }
    if (cropX != null && cropY != null && cropW != null && cropH != null) {
      pre.add('crop=$cropW:$cropH:$cropX:$cropY');
    }
    pre.add('fps=$fps');
    if (scaleW != null) pre.add('scale=$scaleW:-1:flags=lanczos');
    if ((speedFactor - 1.0).abs() > 0.001) {
      pre.add('setpts=${(1.0 / speedFactor).toStringAsFixed(6)}*PTS');
    }
    final chain = pre.join(',');

    final inputOpts = <String>[];
    if (!hasCut && startMs != null && startMs > 0) {
      inputOpts.addAll(['-ss', (startMs / 1000).toStringAsFixed(3)]);
    }
    // -t input-side: limits the decode, not the written stream. With cuts the
    // select filter would otherwise decode to source EOF (keepRanges is sorted,
    // so .last.endMs is where useful frames stop); with speed < 1 an
    // output-side -t would truncate the slowed result.
    if (hasCut) {
      inputOpts
          .addAll(['-t', (keepRanges.last.endMs / 1000).toStringAsFixed(3)]);
    } else if (durationMs != null && durationMs > 0) {
      inputOpts.addAll(['-t', (durationMs / 1000).toStringAsFixed(3)]);
    }

    return (
      palettePass: [
        '-y', ...inputOpts, '-i', inputPath,
        '-vf', '$chain,palettegen=stats_mode=diff',
        palettePath,
      ],
      renderPass: [
        '-y', ...inputOpts, '-i', inputPath, '-i', palettePath,
        '-filter_complex',
        '[0:v] $chain [x];[x][1:v] paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle',
        '-loop', '0',
        '-progress', 'pipe:1',
        outputPath,
      ],
    );
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
    int? startMs,
    int? durationMs,
    String? drawText,
    String? drawTextFont,
    int drawTextSize = 36,
    String drawTextColor = 'white',
    String drawTextPosition = 'center',
    int? fps,
    int loopCount = 0,
    bool boomerang = false,
    bool smoothLoop = false,
    int crossfadeMs = 1000,
  }) {
    if (smoothLoop && boomerang) {
      throw ArgumentError('smoothLoop and boomerang are mutually exclusive');
    }
    if (smoothLoop && (durationMs == null || durationMs <= 0)) {
      throw ArgumentError('smoothLoop requires a positive durationMs');
    }
    if (smoothLoop && fps == null) {
      throw ArgumentError('smoothLoop requires fps (xfade needs CFR input)');
    }
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
    String body;
    if (smoothLoop) {
      final cf = crossfadeMs / 1000;
      final d = durationMs! / 1000 / speedFactor;
      if (d <= 2 * cf + 0.1) {
        throw ArgumentError(
            'smoothLoop: post-speed duration ${d}s too short for a ${cf}s crossfade');
      }
      String f(double v) => v.toStringAsFixed(3);
      body = '$chain,split=3[p0][p1][p2];'
          '[p0]trim=0:${f(cf)},setpts=PTS-STARTPTS[head];'
          '[p1]trim=${f(d - cf)}:${f(d)},setpts=PTS-STARTPTS[tail];'
          '[p2]trim=${f(cf)}:${f(d - cf)},setpts=PTS-STARTPTS[mid];'
          '[tail][head]xfade=transition=fade:duration=${f(cf)}:offset=0[blend];'
          '[mid][blend]concat=n=2:v=1[a0];'
          '[a0]split[a][b]';
    } else if (boomerang) {
      // Boomerang: append a reversed copy of the (edited) stream so the GIF
      // plays forward then backward → seamless ping-pong loop.
      body =
          '$chain,split[fwd][r0];[r0]reverse[rev];[fwd][rev]concat=n=2:v=1,split[a][b]';
    } else {
      body = '$chain,split[a][b]';
    }
    final args = ['-y'];
    if (startMs != null && startMs > 0) {
      args.addAll(['-ss', (startMs / 1000).toStringAsFixed(3)]);
    }
    // -t must stay an input option (before -i): placed after -i it binds to
    // the output instead and truncates the written stream, not the source
    // read — invisible for a plain trim but cuts boomerang's reversed half
    // off entirely, since the write stops mid-forward-segment.
    if (durationMs != null && durationMs > 0) {
      args.addAll(['-t', (durationMs / 1000).toStringAsFixed(3)]);
    }
    args.addAll(['-i', inputPath]);
    args.addAll([
      '-filter_complex',
      '$body;[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5',
      '-loop', '$loopCount',
      '-progress', 'pipe:1',
      outputPath,
    ]);
    return args;
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

  /// Shared VP9/AV1 encoder arg block — used by [toWebm] and the WebM branch
  /// of [videoEdit] so the speed/quality flags live in exactly one place.
  static List<String> _webmEncoderArgs({
    required int crf,
    required int cpuUsed,
    required bool av1,
    required int threads,
  }) {
    final t = threads > 0 ? threads : Platform.numberOfProcessors;
    return av1
        ? [
            '-c:v', 'libaom-av1',
            '-crf', '$crf', '-b:v', '0',
            '-cpu-used', '$cpuUsed',
            '-row-mt', '1', '-tile-columns', '2', '-threads', '$t',
          ]
        : [
            '-c:v', 'libvpx-vp9',
            '-crf', '$crf', '-b:v', '0',
            '-cpu-used', '$cpuUsed',
            '-deadline', 'good',
            '-row-mt', '1', '-tile-columns', '2', '-threads', '$t',
          ];
  }

  /// yuv420p (and gifs generally) require even dimensions. No cap: clamp
  /// source dims down to even. With a cap: clamp the smaller of (cap, source
  /// width) down to even; `-2` keeps height even and proportional. Never
  /// upscales.
  static String _webmScaleFilter(int? maxWidth) => maxWidth == null
      ? 'scale=trunc(iw/2)*2:trunc(ih/2)*2'
      : "scale='trunc(min($maxWidth,iw)/2)*2':-2";

  /// Convert video or GIF to WebM (VP9 by default, AV1 opt-in). [alpha]
  /// (yuva420p, VP9 only — caller forces `av1=false` when alpha is wanted)
  /// preserves GIF transparency. [keepAudio] should be caller-supplied
  /// `MediaInfo.hasAudio` (false for GIF input).
  static List<String> toWebm({
    required String inputPath,
    required String outputPath,
    required int crf,
    required int cpuUsed,
    bool av1 = false,
    int? maxWidth,
    bool keepAudio = false,
    bool alpha = false,
    int threads = 0,
  }) {
    final args = ['-y', '-i', inputPath, '-vf', _webmScaleFilter(maxWidth)];
    final wantAlpha = alpha && !av1;
    args.addAll(['-pix_fmt', wantAlpha ? 'yuva420p' : 'yuv420p']);
    if (wantAlpha) args.addAll(['-auto-alt-ref', '0']);
    args.addAll(_webmEncoderArgs(
        crf: crf, cpuUsed: cpuUsed, av1: av1, threads: threads));
    if (keepAudio) {
      args.addAll(['-c:a', 'libopus', '-b:a', '128k']);
    } else {
      args.add('-an');
    }
    args.addAll(['-progress', 'pipe:1', outputPath]);
    return args;
  }

  static List<String> _encoderArgs(String encoder) => switch (encoder) {
    'h264_nvenc'       => ['-c:v', 'h264_nvenc', '-cq', '23'],
    'h264_qsv'        => ['-c:v', 'h264_qsv', '-global_quality', '23'],
    'h264_amf'        => ['-c:v', 'h264_amf', '-qp_i', '23', '-qp_p', '23'],
    'h264_mediacodec' => ['-c:v', 'h264_mediacodec', '-b:v', '4M'],
    _                 => ['-c:v', 'libx264', '-preset', 'fast', '-crf', '20'],
  };

  /// Screen Record: gdigrab capture of one monitor (physical px offset/size),
  /// optional mic input muxed in the same process (in-process, no sync step).
  /// [width]/[height] are clamped down to even — yuv420p requires it.
  /// [targetHeight], if given and smaller than the captured [height], adds a
  /// `-vf scale=-2:targetHeight` downscale (encoded directly here, not a
  /// later pass — concat/finalize stays `-c copy`). Never upscales.
  static List<String> screenCapture({
    required String outputPath,
    required int offsetX,
    required int offsetY,
    required int width,
    required int height,
    int framerate = 30,
    required int durationSeconds,
    String? micDeviceName,
    int? targetHeight,
  }) {
    final w = (width ~/ 2) * 2;
    final h = (height ~/ 2) * 2;
    final args = [
      '-y',
      '-nostats', '-loglevel', 'warning',
      '-f', 'gdigrab',
      '-framerate', '$framerate',
      '-offset_x', '$offsetX',
      '-offset_y', '$offsetY',
      '-video_size', '${w}x$h',
      '-draw_mouse', '1',
      '-i', 'desktop',
    ];
    if (micDeviceName != null) {
      args.addAll(['-f', 'dshow', '-i', 'audio=$micDeviceName']);
    }
    if (targetHeight != null && targetHeight < h) {
      args.addAll(['-vf', 'scale=-2:$targetHeight']);
    }
    args.addAll(['-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '23', '-pix_fmt', 'yuv420p']);
    if (micDeviceName != null) {
      args.addAll(['-c:a', 'aac', '-b:a', '160k']);
    }
    args.addAll(['-t', '$durationSeconds', outputPath]);
    return args;
  }

  /// Lists DirectShow devices; caller parses device names from stderr.
  static List<String> listDshowDevicesArgs() =>
      ['-list_devices', 'true', '-f', 'dshow', '-i', 'dummy'];

  /// Builds a concat demuxer list file (no per-entry duration — segments
  /// already carry their own timing) for [segmentPaths].
  static String buildSegmentConcatListContent(List<String> segmentPaths) {
    final buf = StringBuffer();
    for (final path in segmentPaths) {
      final escaped = path.replaceAll('\\', '/').replaceAll("'", r"\'");
      buf.writeln("file '$escaped'");
    }
    return buf.toString();
  }

  /// Stream-copy concat of recording segments (video, or audio wavs) via the
  /// concat demuxer — lossless, near-instant.
  static List<String> concatSegments({
    required String listFilePath,
    required String outputPath,
  }) =>
      ['-y', '-f', 'concat', '-safe', '0', '-i', listFilePath, '-c', 'copy', outputPath];

  /// Finalize mux: bakes the system-audio loopback WAV (and, if the video
  /// already carries a mic AAC track, mixes both) into the recorded video.
  /// [itsOffsetSeconds] compensates the loopback-start vs. first-frame delta.
  static List<String> muxAudio({
    required String videoPath,
    required String audioPath,
    required String outputPath,
    bool videoHasAudio = false,
    double itsOffsetSeconds = 0,
  }) {
    final args = ['-y', '-i', videoPath];
    if (itsOffsetSeconds.abs() > 0.001) {
      args.addAll(['-itsoffset', itsOffsetSeconds.toStringAsFixed(3)]);
    }
    args.addAll(['-i', audioPath]);
    if (videoHasAudio) {
      args.addAll([
        '-filter_complex', '[0:a][1:a]amix=inputs=2:duration=first[a]',
        '-map', '0:v', '-map', '[a]',
      ]);
    } else {
      args.addAll(['-map', '0:v', '-map', '1:a']);
    }
    args.addAll(['-c:v', 'copy', '-c:a', 'aac', '-b:a', '160k', outputPath]);
    return args;
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
    // Repeat last frame without duration so concat demuxer honors its duration
    if (framePaths.isNotEmpty) {
      final lastEscaped =
          framePaths.last.replaceAll('\\', '/').replaceAll("'", r"\'");
      buf.writeln("file '$lastEscaped'");
    }
    return buf.toString();
  }
}
