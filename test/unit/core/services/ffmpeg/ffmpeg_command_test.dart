import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_command.dart';


void main() {
  group('FfmpegCommand.imagesToGif', () {
    test('includes concat demuxer flags and paths', () {
      final args = FfmpegCommand.imagesToGif(
        concatFilePath: '/job/concat.txt',
        outputPath: '/job/output.gif',
      );
      expect(
        args,
        containsAll(['-f', 'concat', '-safe', '0', '-i', '/job/concat.txt', '/job/output.gif']),
      );
    });

    test('no scale= prefix when width is null', () {
      final args = FfmpegCommand.imagesToGif(
        concatFilePath: '/job/concat.txt',
        outputPath: '/job/output.gif',
      );
      final filter = args.firstWhere((a) => a.contains('split'));
      expect(filter, isNot(startsWith('scale=')));
    });

    test('scale= injected when width given', () {
      final args = FfmpegCommand.imagesToGif(
        concatFilePath: '/job/concat.txt',
        outputPath: '/job/output.gif',
        width: 320,
      );
      final filter = args.firstWhere((a) => a.contains('scale'));
      expect(filter, contains('scale=320'));
    });

    test('filter contains palettegen and paletteuse', () {
      final args = FfmpegCommand.imagesToGif(
          concatFilePath: '/x', outputPath: '/y');
      final filter = args.firstWhere((a) => a.contains('palettegen'));
      expect(filter, contains('paletteuse'));
    });

    test('-loop 0 (infinite loop)', () {
      final args =
          FfmpegCommand.imagesToGif(concatFilePath: '/x', outputPath: '/y');
      final loopIdx = args.indexOf('-loop');
      expect(loopIdx, isNot(-1));
      expect(args[loopIdx + 1], equals('0'));
    });
  });

  group('FfmpegCommand.videoToGif', () {
    test('no seek flags when start/duration null', () {
      final args =
          FfmpegCommand.videoToGif(inputPath: '/in.mp4', outputPath: '/out.gif');
      expect(args, isNot(contains('-ss')));
      expect(args, isNot(contains('-t')));
    });

    test('-ss added when start provided', () {
      final args = FfmpegCommand.videoToGif(
        inputPath: '/in.mp4',
        outputPath: '/out.gif',
        start: const Duration(seconds: 2),
      );
      expect(args, contains('-ss'));
      expect(args, contains('2.000'));
    });

    test('-t added when duration provided', () {
      final args = FfmpegCommand.videoToGif(
        inputPath: '/in.mp4',
        outputPath: '/out.gif',
        duration: const Duration(milliseconds: 1500),
      );
      expect(args, contains('-t'));
      expect(args, contains('1.500'));
    });

    test('fps embedded in filter', () {
      final args = FfmpegCommand.videoToGif(
          inputPath: '/in.mp4', outputPath: '/out.gif', fps: 20);
      final filter = args.firstWhere((a) => a.contains('fps='));
      expect(filter, contains('fps=20'));
    });

    test('scale= in filter when width given', () {
      final args = FfmpegCommand.videoToGif(
          inputPath: '/in.mp4', outputPath: '/out.gif', width: 480);
      final filter = args.firstWhere((a) => a.contains('scale='));
      expect(filter, contains('scale=480'));
    });
  });

  group('FfmpegCommand.cropGif', () {
    test('filter contains crop dimensions in WxH:X:Y order', () {
      final args = FfmpegCommand.cropGif(
        inputPath: '/in.gif',
        outputPath: '/out.gif',
        x: 10,
        y: 20,
        cropWidth: 100,
        cropHeight: 80,
      );
      final filter = args.firstWhere((a) => a.contains('crop='));
      expect(filter, contains('crop=100:80:10:20'));
    });
  });

  group('FfmpegCommand.resize', () {
    test('width only → height=-1', () {
      final args =
          FfmpegCommand.resize(inputPath: '/in.gif', outputPath: '/out.gif', width: 320);
      final filter = args.firstWhere((a) => a.contains('scale='));
      expect(filter, contains('scale=320:-1'));
    });

    test('both null → scale=-1:-1', () {
      final args =
          FfmpegCommand.resize(inputPath: '/in.gif', outputPath: '/out.gif');
      final filter = args.firstWhere((a) => a.contains('scale='));
      expect(filter, contains('scale=-1:-1'));
    });

    test('height only → width=-1', () {
      final args = FfmpegCommand.resize(
          inputPath: '/in.gif', outputPath: '/out.gif', height: 240);
      final filter = args.firstWhere((a) => a.contains('scale='));
      expect(filter, contains('scale=-1:240'));
    });
  });

  group('FfmpegCommand.changeSpeed', () {
    test('2x speed → setpts=0.500000*PTS', () {
      final args = FfmpegCommand.changeSpeed(
          inputPath: '/in.gif', outputPath: '/out.gif', factor: 2.0);
      final filter = args.firstWhere((a) => a.contains('setpts='));
      expect(filter, contains('setpts=0.500000'));
    });

    test('0.5x speed → setpts=2.000000*PTS', () {
      final args = FfmpegCommand.changeSpeed(
          inputPath: '/in.gif', outputPath: '/out.gif', factor: 0.5);
      final filter = args.firstWhere((a) => a.contains('setpts='));
      expect(filter, contains('setpts=2.000000'));
    });
  });

  group('FfmpegCommand.reverseGif', () {
    test('filter contains reverse keyword', () {
      final args =
          FfmpegCommand.reverseGif(inputPath: '/in.gif', outputPath: '/out.gif');
      final filter = args.firstWhere((a) => a.contains('reverse'));
      expect(filter, contains('reverse'));
    });
  });

  group('FfmpegCommand.textOverlay', () {
    test('drawtext includes text, fontsize, fontcolor', () {
      final args = FfmpegCommand.textOverlay(
        inputPath: '/in.gif',
        outputPath: '/out.gif',
        text: 'Hello',
        fontFile: '/fonts/arial.ttf',
        fontSize: 48,
        fontColor: 'yellow',
        position: 'top',
      );
      final filter = args.firstWhere((a) => a.contains('drawtext='));
      expect(filter, contains("text='Hello'"));
      expect(filter, contains('fontsize=48'));
      expect(filter, contains('fontcolor=yellow'));
    });

    test('colon in text is escaped', () {
      final args = FfmpegCommand.textOverlay(
        inputPath: '/in.gif',
        outputPath: '/out.gif',
        text: 'A:B',
        fontFile: '/f.ttf',
      );
      final filter = args.firstWhere((a) => a.contains('drawtext='));
      expect(filter, contains(r'A\:B'));
    });

    test('apostrophe in text is single-quote-escaped (not bare backslash)', () {
      // Regression: ffmpeg treats `\` as literal inside '...', so `\'` leaves
      // the quote open and the trailing ,split gets swallowed → EINVAL (-22).
      // The literal apostrophe must be emitted as '\'' (close/escape/reopen).
      final args = FfmpegCommand.textOverlay(
        inputPath: '/in.gif',
        outputPath: '/out.gif',
        text: "it's",
        fontFile: '/f.ttf',
      );
      final filter = args.firstWhere((a) => a.contains('drawtext='));
      expect(filter, contains("text='it'\\''s'"));
      expect(filter, isNot(contains("\\'s'")));
    });

    test('top position: y=fontSize', () {
      final args = FfmpegCommand.textOverlay(
        inputPath: '/in.gif',
        outputPath: '/out.gif',
        text: 'Hi',
        fontFile: '/f.ttf',
        fontSize: 36,
        position: 'top',
      );
      final filter = args.firstWhere((a) => a.contains('drawtext='));
      expect(filter, contains('y=36'));
    });

    test('bottom position: y=h-text_h-fontSize', () {
      final args = FfmpegCommand.textOverlay(
        inputPath: '/in.gif',
        outputPath: '/out.gif',
        text: 'Hi',
        fontFile: '/f.ttf',
        fontSize: 36,
        position: 'bottom',
      );
      final filter = args.firstWhere((a) => a.contains('drawtext='));
      expect(filter, contains('y=h-text_h-36'));
    });

    test('center position: y=(h-text_h)/2', () {
      final args = FfmpegCommand.textOverlay(
        inputPath: '/in.gif',
        outputPath: '/out.gif',
        text: 'Hi',
        fontFile: '/f.ttf',
        position: 'center',
      );
      final filter = args.firstWhere((a) => a.contains('drawtext='));
      expect(filter, contains('y=(h-text_h)/2'));
    });

    test('Windows font path backslashes converted and drive colon escaped', () {
      final args = FfmpegCommand.textOverlay(
        inputPath: '/in.gif',
        outputPath: '/out.gif',
        text: 'Hi',
        fontFile: r'C:\Windows\Fonts\arial.ttf',
      );
      final filter = args.firstWhere((a) => a.contains('drawtext='));
      expect(filter, contains(r'C\:/Windows/Fonts/arial.ttf'));
    });
  });

  group('FfmpegCommand.videoEdit textSpecs', () {
    test('drawtext bakes before crop/scale so text scales with content', () {
      final args = FfmpegCommand.videoEdit(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        encoder: 'libx264',
        cropX: 10,
        cropY: 20,
        cropW: 100,
        cropH: 80,
        textSpecs: const [
          DrawTextSpec(
            text: 'Hi',
            fontFile: '/f.ttf',
            x: 5,
            y: 6,
            fontSize: 30,
            fontColorHex: 'FFFFFF',
            strokeColorHex: '000000',
            strokeWidth: 0,
          ),
        ],
      );
      final vf = args[args.indexOf('-vf') + 1];
      expect(vf, contains('drawtext='));
      expect(vf.indexOf('drawtext='), lessThan(vf.indexOf('crop=')));
    });

    test('no drawtext when textSpecs null', () {
      final args = FfmpegCommand.videoEdit(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        encoder: 'libx264',
      );
      final vf = args[args.indexOf('-vf') + 1];
      expect(vf, isNot(contains('drawtext=')));
    });
  });

  group('FfmpegCommand.videoEdit volume', () {
    test('volume filter added to -af when changed and audio present', () {
      final args = FfmpegCommand.videoEdit(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        encoder: 'libx264',
        hasAudio: true,
        volume: 1.5,
      );
      final af = args[args.indexOf('-af') + 1];
      expect(af, contains('volume=1.500'));
    });

    test('volume chains after atempo when speed also changed', () {
      final args = FfmpegCommand.videoEdit(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        encoder: 'libx264',
        hasAudio: true,
        speedFactor: 2.0,
        volume: 0.5,
      );
      final af = args[args.indexOf('-af') + 1];
      expect(af.indexOf('atempo'), lessThan(af.indexOf('volume=')));
    });

    test('no -af when volume unchanged and no speed change', () {
      final args = FfmpegCommand.videoEdit(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        encoder: 'libx264',
        hasAudio: true,
      );
      expect(args.contains('-af'), isFalse);
    });

    test('volume ignored when no audio (-an)', () {
      final args = FfmpegCommand.videoEdit(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        encoder: 'libx264',
        volume: 2.0,
      );
      expect(args.contains('-an'), isTrue);
      expect(args.contains('-af'), isFalse);
    });
  });

  group('FfmpegCommand.videoEdit with keepRanges (cuts)', () {
    const twoRanges = <CutSegment>[
      (startMs: 0, endMs: 3000),
      (startMs: 5000, endMs: 10000),
    ];

    test('select+setpts prepended to -vf, no -ss/-t', () {
      final args = FfmpegCommand.videoEdit(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        encoder: 'libx264',
        keepRanges: twoRanges,
        startMs: 0,
        durationMs: 10000,
      );
      final vf = args[args.indexOf('-vf') + 1];
      expect(vf, contains("select='between(t,0.000,3.000)+between(t,5.000,10.000)',setpts=N/FRAME_RATE/TB"));
      expect(args, isNot(contains('-ss')));
      expect(args, isNot(contains('-t')));
    });

    test('hasAudio → aselect+asetpts first in -af', () {
      final args = FfmpegCommand.videoEdit(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        encoder: 'libx264',
        hasAudio: true,
        keepRanges: twoRanges,
      );
      final af = args[args.indexOf('-af') + 1];
      expect(
        af,
        contains("aselect='between(t,0.000,3.000)+between(t,5.000,10.000)',asetpts=N/SR/TB"),
      );
    });

    test('videoEditToGif: select first in filtergraph, before fps', () {
      final cmds = FfmpegCommand.videoEditToGif(
        inputPath: '/in.mp4',
        outputPath: '/out.gif',
        palettePath: '/palette.png',
        keepRanges: twoRanges,
      );
      final args = cmds.renderPass;
      final fc = args[args.indexOf('-filter_complex') + 1];
      expect(fc.indexOf('select='), lessThan(fc.indexOf('fps=')));
      expect(args, isNot(contains('-ss')));
      // Decode stops at the last keep range end (input-side -t).
      expect(args.indexOf('-t'), lessThan(args.indexOf('-i')));
      expect(args[args.indexOf('-t') + 1], equals('10.000'));
    });

    test('videoEditToGif: two passes share input opts and chain', () {
      final cmds = FfmpegCommand.videoEditToGif(
        inputPath: '/in.mp4',
        outputPath: '/out.gif',
        palettePath: '/palette.png',
        startMs: 1000,
        durationMs: 5000,
        fps: 12,
        scaleW: 800,
      );
      final pal = cmds.palettePass;
      final ren = cmds.renderPass;
      // -ss/-t are input-side (before -i) on both passes.
      for (final args in [pal, ren]) {
        expect(args.indexOf('-ss'), lessThan(args.indexOf('-i')));
        expect(args[args.indexOf('-ss') + 1], equals('1.000'));
        expect(args.indexOf('-t'), lessThan(args.indexOf('-i')));
        expect(args[args.indexOf('-t') + 1], equals('5.000'));
      }
      // Palette pass: single chain into palettegen, writes the palette.
      expect(pal.last, equals('/palette.png'));
      final vf = pal[pal.indexOf('-vf') + 1];
      expect(vf, contains('fps=12,scale=800:-1'));
      expect(vf, contains('palettegen=stats_mode=diff'));
      expect(vf, isNot(contains('split')));
      // Render pass: palette is the second input, no split/palettegen.
      expect(ren.last, equals('/out.gif'));
      expect(ren.where((a) => a == '-i').length, equals(2));
      expect(ren[ren.lastIndexOf('-i') + 1], equals('/palette.png'));
      final fc = ren[ren.indexOf('-filter_complex') + 1];
      expect(fc, contains('fps=12,scale=800:-1'));
      expect(fc, contains('[1:v] paletteuse'));
      expect(fc, isNot(contains('palettegen')));
    });

    test('null keepRanges → -ss/-t path unchanged (regression guard)', () {
      final without = FfmpegCommand.videoEdit(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        encoder: 'libx264',
        startMs: 1000,
        durationMs: 5000,
      );
      final withNull = FfmpegCommand.videoEdit(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        encoder: 'libx264',
        startMs: 1000,
        durationMs: 5000,
        keepRanges: null,
      );
      expect(without, equals(withNull));
      expect(withNull, contains('-ss'));
      expect(withNull, contains('-t'));
    });
  });

  group('FfmpegCommand.buildConcatFileContent', () {
    test('15fps → duration 0.066667 per frame', () {
      final content =
          FfmpegCommand.buildConcatFileContent(['/a.png', '/b.png'], 15);
      expect(content, contains('duration 0.066667'));
    });

    test('non-last frame appears once, last frame repeated for duration fix', () {
      final content =
          FfmpegCommand.buildConcatFileContent(['/a.png', '/b.png'], 10);
      expect("file '/a.png'".allMatches(content).length, equals(1));
      expect("file '/b.png'".allMatches(content).length, equals(2));
    });

    test('last frame sentinel has no trailing duration', () {
      final content =
          FfmpegCommand.buildConcatFileContent(['/a.png', '/b.png'], 10);
      final lines = content.trimRight().split('\n');
      // sentinel is last line; preceding line is the real frame's duration
      expect(lines.last, equals("file '/b.png'"));
      expect(lines[lines.length - 2], startsWith('duration'));
    });

    test('backslash in path converted to forward slash', () {
      final content = FfmpegCommand.buildConcatFileContent(
          [r'C:\frames\a.png'], 10);
      expect(content, contains("file 'C:/frames/a.png'"));
    });

    test('10fps → duration 0.100000 per frame', () {
      final content =
          FfmpegCommand.buildConcatFileContent(['/x.png'], 10);
      expect(content, contains('duration 0.100000'));
    });
  });
}
