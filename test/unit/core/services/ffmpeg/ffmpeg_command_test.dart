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
