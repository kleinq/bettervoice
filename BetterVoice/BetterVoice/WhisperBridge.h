//
//  WhisperBridge.h
//  BetterVoice
//
//  C wrapper for whisper.cpp to simplify bridging to Swift
//

#ifndef WhisperBridge_h
#define WhisperBridge_h

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque pointer to whisper context
typedef struct whisper_context whisper_context;

// Initialize whisper from model file
whisper_context* whisper_bridge_init(const char* model_path);

// Free whisper context
void whisper_bridge_free(whisper_context* ctx);

// Transcribe audio data
// Returns transcribed text (caller must free)
char* whisper_bridge_transcribe(
    whisper_context* ctx,
    const float* audio_data,
    int audio_length,
    const char* language,
    bool translate,
    const char* initial_prompt  // Custom vocabulary/context hint
);

// Check if context is valid
bool whisper_bridge_is_valid(whisper_context* ctx);

#ifdef __cplusplus
}
#endif

#endif /* WhisperBridge_h */
