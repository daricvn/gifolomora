#ifndef RUNNER_AUDIO_LOOPBACK_H_
#define RUNNER_AUDIO_LOOPBACK_H_

#include <windows.h>
#include <mmdeviceapi.h>
#include <audioclient.h>

#include <atomic>
#include <cstdint>
#include <cstdio>
#include <string>
#include <thread>

// WASAPI loopback capture of the default render device, written to a WAV
// file. One instance is reused across a recording's segments — Start/Stop is
// called once per ffmpeg video segment so pause/resume needs no audio
// surgery (the WAVs concat with the same list mechanism as the video).
//
// Silence handling: WASAPI keeps delivering buffers tagged
// AUDCLNT_BUFFERFLAGS_SILENT while nothing is rendering (the engine doesn't
// simply stop producing packets) — writing real zero bytes for those buffers
// keeps the WAV's wall-clock duration in step with the video segment instead
// of drifting short.
class AudioLoopback {
 public:
  AudioLoopback();
  ~AudioLoopback();

  // Starts capturing to |path| (overwritten if it exists). Returns false on
  // any device/COM failure — caller surfaces this as a toggle-off, not fatal
  // to the recording itself.
  bool Start(const std::wstring& path);

  // Stops capturing and finalizes the WAV header (patches the size fields
  // now that the data length is known). Returns captured duration in ms.
  int64_t Stop();

 private:
  void CaptureThreadProc();
  void WriteWavHeader(DWORD dataSize);
  void ReleaseAll();

  std::thread thread_;
  std::atomic<bool> running_{false};
  bool com_initialized_here_ = false;

  FILE* file_ = nullptr;
  DWORD data_bytes_written_ = 0;

  WORD format_tag_ = 1;       // WAVE_FORMAT_PCM by default; set from mix format
  WORD channels_ = 2;
  DWORD sample_rate_ = 48000;
  WORD bits_per_sample_ = 32;

  IMMDeviceEnumerator* enumerator_ = nullptr;
  IMMDevice* device_ = nullptr;
  IAudioClient* audio_client_ = nullptr;
  IAudioCaptureClient* capture_client_ = nullptr;
  WAVEFORMATEX* mix_format_ = nullptr;
};

#endif  // RUNNER_AUDIO_LOOPBACK_H_
