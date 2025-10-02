//
//  WhisperBridge.cpp
//  BetterVoice
//
//  C++ implementation of whisper.cpp bridge
//

#include "WhisperBridge.h"
#include "../whisper.cpp/include/whisper.h"
#include <string.h>
#include <stdlib.h>

extern "C" {

whisper_context* whisper_bridge_init(const char* model_path) {
    struct whisper_context_params cparams = whisper_context_default_params();
    return whisper_init_from_file_with_params(model_path, cparams);
}

void whisper_bridge_free(whisper_context* ctx) {
    if (ctx) {
        whisper_free(ctx);
    }
}

char* whisper_bridge_transcribe(
    whisper_context* ctx,
    const float* audio_data,
    int audio_length,
    const char* language,
    bool translate
) {
    if (!ctx || !audio_data || audio_length <= 0) {
        return nullptr;
    }

    // Set up whisper parameters
    struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.print_progress = false;
    params.print_timestamps = false;
    params.print_special = false;
    params.translate = translate;
    if (language) {
        params.language = language;
    }

    // Run transcription
    int result = whisper_full(ctx, params, audio_data, audio_length);
    if (result != 0) {
        return nullptr;
    }

    // Collect all segments into single string
    const int n_segments = whisper_full_n_segments(ctx);
    size_t total_length = 0;

    // Calculate total length
    for (int i = 0; i < n_segments; i++) {
        const char* text = whisper_full_get_segment_text(ctx, i);
        if (text) {
            total_length += strlen(text);
        }
    }

    // Allocate result buffer
    char* result_text = (char*)malloc(total_length + 1);
    if (!result_text) {
        return nullptr;
    }

    // Concatenate segments
    result_text[0] = '\0';
    for (int i = 0; i < n_segments; i++) {
        const char* text = whisper_full_get_segment_text(ctx, i);
        if (text) {
            strcat(result_text, text);
        }
    }

    return result_text;
}

bool whisper_bridge_is_valid(whisper_context* ctx) {
    return ctx != nullptr;
}

} // extern "C"
