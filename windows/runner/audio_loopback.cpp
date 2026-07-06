#include "audio_loopback.h"

#include <mmreg.h>

#include <vector>

namespace {
// KSDATAFORMAT_SUBTYPE_IEEE_FLOAT / _PCM live in ksmedia.h, which pulls in
// the ksuser/ksguid libs. The GUID values are stable Windows constants —
// declaring them locally avoids adding link dependencies for two bytes of
// comparison.
const GUID kSubtypeIeeeFloat = {
    0x00000003, 0x0000, 0x0010, {0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71}};
const GUID kSubtypePcm = {
    0x00000001, 0x0000, 0x0010, {0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71}};
}  // namespace

AudioLoopback::AudioLoopback() {}

AudioLoopback::~AudioLoopback() {
  if (running_) Stop();
}

bool AudioLoopback::Start(const std::wstring& path) {
  if (running_) return false;
  data_bytes_written_ = 0;

  HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  com_initialized_here_ = SUCCEEDED(hr);
  // RPC_E_CHANGED_MODE means COM is already initialized (STA) on this
  // thread by the Flutter engine — still usable, just don't uninit it later.

  hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                        __uuidof(IMMDeviceEnumerator), (void**)&enumerator_);
  if (FAILED(hr)) { ReleaseAll(); return false; }

  hr = enumerator_->GetDefaultAudioEndpoint(eRender, eConsole, &device_);
  if (FAILED(hr)) { ReleaseAll(); return false; }

  hr = device_->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                         (void**)&audio_client_);
  if (FAILED(hr)) { ReleaseAll(); return false; }

  hr = audio_client_->GetMixFormat(&mix_format_);
  if (FAILED(hr)) { ReleaseAll(); return false; }

  channels_ = mix_format_->nChannels;
  sample_rate_ = mix_format_->nSamplesPerSec;
  bits_per_sample_ = mix_format_->wBitsPerSample;
  format_tag_ = mix_format_->wFormatTag;
  if (format_tag_ == WAVE_FORMAT_EXTENSIBLE) {
    auto* ext = reinterpret_cast<WAVEFORMATEXTENSIBLE*>(mix_format_);
    if (IsEqualGUID(ext->SubFormat, kSubtypeIeeeFloat)) {
      format_tag_ = WAVE_FORMAT_IEEE_FLOAT;
    } else if (IsEqualGUID(ext->SubFormat, kSubtypePcm)) {
      format_tag_ = WAVE_FORMAT_PCM;
    }
  }

  hr = audio_client_->Initialize(AUDCLNT_SHAREMODE_SHARED,
                                 AUDCLNT_STREAMFLAGS_LOOPBACK,
                                 10000000,  // 1s engine buffer
                                 0, mix_format_, nullptr);
  if (FAILED(hr)) { ReleaseAll(); return false; }

  hr = audio_client_->GetService(__uuidof(IAudioCaptureClient),
                                (void**)&capture_client_);
  if (FAILED(hr)) { ReleaseAll(); return false; }

  _wfopen_s(&file_, path.c_str(), L"wb");
  if (!file_) { ReleaseAll(); return false; }
  WriteWavHeader(0);  // placeholder — patched with real sizes in Stop()

  hr = audio_client_->Start();
  if (FAILED(hr)) {
    fclose(file_);
    file_ = nullptr;
    ReleaseAll();
    return false;
  }

  running_ = true;
  thread_ = std::thread(&AudioLoopback::CaptureThreadProc, this);
  return true;
}

void AudioLoopback::CaptureThreadProc() {
  const UINT32 frameBytes = (bits_per_sample_ / 8) * channels_;
  while (running_) {
    UINT32 packetLength = 0;
    HRESULT hr = capture_client_->GetNextPacketSize(&packetLength);
    while (SUCCEEDED(hr) && packetLength != 0) {
      BYTE* data = nullptr;
      UINT32 numFrames = 0;
      DWORD flags = 0;
      hr = capture_client_->GetBuffer(&data, &numFrames, &flags, nullptr, nullptr);
      if (FAILED(hr)) break;

      const UINT32 bytes = numFrames * frameBytes;
      if (flags & AUDCLNT_BUFFERFLAGS_SILENT) {
        std::vector<BYTE> silence(bytes, 0);
        fwrite(silence.data(), 1, bytes, file_);
      } else {
        fwrite(data, 1, bytes, file_);
      }
      data_bytes_written_ += bytes;

      capture_client_->ReleaseBuffer(numFrames);
      hr = capture_client_->GetNextPacketSize(&packetLength);
    }
    Sleep(10);
  }
}

int64_t AudioLoopback::Stop() {
  if (!running_) return 0;
  running_ = false;
  if (thread_.joinable()) thread_.join();

  if (audio_client_) audio_client_->Stop();

  if (file_) {
    fseek(file_, 0, SEEK_SET);
    WriteWavHeader(data_bytes_written_);
    fclose(file_);
    file_ = nullptr;
  }

  const DWORD frameBytes = (bits_per_sample_ / 8) * channels_;
  const int64_t totalFrames =
      frameBytes > 0 ? static_cast<int64_t>(data_bytes_written_) / frameBytes : 0;
  const int64_t ms =
      sample_rate_ > 0 ? (totalFrames * 1000) / sample_rate_ : 0;

  ReleaseAll();
  return ms;
}

void AudioLoopback::ReleaseAll() {
  if (capture_client_) { capture_client_->Release(); capture_client_ = nullptr; }
  if (audio_client_) { audio_client_->Release(); audio_client_ = nullptr; }
  if (device_) { device_->Release(); device_ = nullptr; }
  if (enumerator_) { enumerator_->Release(); enumerator_ = nullptr; }
  if (mix_format_) { CoTaskMemFree(mix_format_); mix_format_ = nullptr; }
  if (com_initialized_here_) { CoUninitialize(); com_initialized_here_ = false; }
}

void AudioLoopback::WriteWavHeader(DWORD dataSize) {
  const DWORD byteRate = sample_rate_ * channels_ * (bits_per_sample_ / 8);
  const WORD blockAlign = static_cast<WORD>(channels_ * (bits_per_sample_ / 8));
  const DWORD riffSize = 36 + dataSize;
  const DWORD fmtSize = 16;

  fwrite("RIFF", 1, 4, file_);
  fwrite(&riffSize, 4, 1, file_);
  fwrite("WAVE", 1, 4, file_);
  fwrite("fmt ", 1, 4, file_);
  fwrite(&fmtSize, 4, 1, file_);
  fwrite(&format_tag_, 2, 1, file_);
  fwrite(&channels_, 2, 1, file_);
  fwrite(&sample_rate_, 4, 1, file_);
  fwrite(&byteRate, 4, 1, file_);
  fwrite(&blockAlign, 2, 1, file_);
  fwrite(&bits_per_sample_, 2, 1, file_);
  fwrite("data", 1, 4, file_);
  fwrite(&dataSize, 4, 1, file_);
}
