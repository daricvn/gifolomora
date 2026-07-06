import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_command.dart';

void main() {
  group('screenCapture', () {
    test('builds gdigrab args with even-clamped dims, no audio', () {
      final args = FfmpegCommand.screenCapture(
        outputPath: 'out.mkv',
        offsetX: -1920,
        offsetY: 0,
        width: 1921,
        height: 1081,
        durationSeconds: 600,
      );
      expect(args, containsAllInOrder(['-f', 'gdigrab']));
      expect(args, containsAllInOrder(['-offset_x', '-1920', '-offset_y', '0']));
      expect(args, containsAllInOrder(['-video_size', '1920x1080']));
      expect(args, containsAllInOrder(['-draw_mouse', '1', '-i', 'desktop']));
      expect(args, containsAllInOrder(['-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '23', '-pix_fmt', 'yuv420p']));
      expect(args, containsAllInOrder(['-t', '600', 'out.mkv']));
      expect(args, isNot(contains('dshow')));
    });

    test('adds dshow mic input + aac in the same process', () {
      final args = FfmpegCommand.screenCapture(
        outputPath: 'out.mkv',
        offsetX: 0,
        offsetY: 0,
        width: 1920,
        height: 1080,
        durationSeconds: 60,
        micDeviceName: 'Microphone (Realtek)',
      );
      expect(args, containsAllInOrder(['-f', 'dshow', '-i', 'audio=Microphone (Realtek)']));
      expect(args, containsAllInOrder(['-c:a', 'aac', '-b:a', '160k']));
    });

    test('adds -vf scale when targetHeight is below captured height', () {
      final args = FfmpegCommand.screenCapture(
        outputPath: 'out.mkv',
        offsetX: 0,
        offsetY: 0,
        width: 1920,
        height: 1080,
        durationSeconds: 60,
        targetHeight: 720,
      );
      expect(args, containsAllInOrder(['-vf', 'scale=-2:720', '-c:v']));
    });

    test('skips -vf scale when targetHeight would upscale', () {
      final args = FfmpegCommand.screenCapture(
        outputPath: 'out.mkv',
        offsetX: 0,
        offsetY: 0,
        width: 1280,
        height: 720,
        durationSeconds: 60,
        targetHeight: 1080,
      );
      expect(args, isNot(contains('-vf')));
    });

    test('skips -vf scale when targetHeight is null (Original)', () {
      final args = FfmpegCommand.screenCapture(
        outputPath: 'out.mkv',
        offsetX: 0,
        offsetY: 0,
        width: 1920,
        height: 1080,
        durationSeconds: 60,
      );
      expect(args, isNot(contains('-vf')));
    });
  });

  test('concatSegments stream-copies via concat demuxer', () {
    final args = FfmpegCommand.concatSegments(
      listFilePath: 'list.txt',
      outputPath: 'out.mp4',
    );
    expect(args, [
      '-y', '-f', 'concat', '-safe', '0', '-i', 'list.txt', '-c', 'copy', 'out.mp4',
    ]);
  });

  test('buildSegmentConcatListContent lists files without duration lines', () {
    final content = FfmpegCommand.buildSegmentConcatListContent([
      r'C:\temp\seg_000.mkv',
      r"C:\temp\it's.mkv",
    ]);
    expect(content, "file 'C:/temp/seg_000.mkv'\nfile 'C:/temp/it\\'s.mkv'\n");
  });

  group('muxAudio', () {
    test('maps audio-only wav onto video with no existing audio track', () {
      final args = FfmpegCommand.muxAudio(
        videoPath: 'video.mp4',
        audioPath: 'sys.wav',
        outputPath: 'out.mp4',
      );
      expect(args, containsAllInOrder(['-i', 'video.mp4', '-i', 'sys.wav']));
      expect(args, containsAllInOrder(['-map', '0:v', '-map', '1:a']));
      expect(args, isNot(contains('amix')));
      expect(args.last, 'out.mp4');
    });

    test('mixes mic (already in video) with system audio via amix', () {
      final args = FfmpegCommand.muxAudio(
        videoPath: 'video.mp4',
        audioPath: 'sys.wav',
        outputPath: 'out.mp4',
        videoHasAudio: true,
      );
      expect(args, contains('[0:a][1:a]amix=inputs=2:duration=first[a]'));
      expect(args, containsAllInOrder(['-map', '0:v', '-map', '[a]']));
    });

    test('applies -itsoffset before the audio input for sync correction', () {
      final args = FfmpegCommand.muxAudio(
        videoPath: 'video.mp4',
        audioPath: 'sys.wav',
        outputPath: 'out.mp4',
        itsOffsetSeconds: 0.045,
      );
      expect(args, containsAllInOrder(['-itsoffset', '0.045', '-i', 'sys.wav']));
    });
  });
}
