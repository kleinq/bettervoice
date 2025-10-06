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
    // Enable GPU but disable flash attention to avoid Metal decoder bug
    cparams.use_gpu = true;
    cparams.flash_attn = false;
    fprintf(stderr, "whisper_bridge_init: GPU enabled, flash attention disabled\n");
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
    bool translate,
    const char* initial_prompt
) {
    if (!ctx || !audio_data || audio_length <= 0) {
        fprintf(stderr, "whisper_bridge: Invalid input - ctx=%p, audio_data=%p, audio_length=%d\n",
                ctx, audio_data, audio_length);
        return nullptr;
    }

    // Debug: Check audio data statistics
    float max_val = 0.0f;
    float sum = 0.0f;
    for (int i = 0; i < audio_length; i++) {
        float abs_val = audio_data[i] < 0 ? -audio_data[i] : audio_data[i];
        if (abs_val > max_val) max_val = abs_val;
        sum += abs_val;
    }
    float avg_val = sum / audio_length;
    fprintf(stderr, "whisper_bridge: audio stats - length=%d, max=%.6f, avg=%.6f\n",
            audio_length, max_val, avg_val);

    // Use default parameters with critical settings
    struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);

    // Set n_threads - CRITICAL! (from cli.cpp example)
    params.n_threads = 4;

    // Set language and basic params
    params.language = "en";
    params.translate = translate;
    params.print_progress = false;
    params.print_special = false;

    fprintf(stderr, "whisper_bridge: Using default parameters with n_threads=%d\n", params.n_threads);

    if (language) {
        params.language = language;
    }
    if (initial_prompt) {
        params.initial_prompt = initial_prompt;
    }

    // Run transcription
    fprintf(stderr, "whisper_bridge: calling whisper_full()...\n");
    int result = whisper_full(ctx, params, audio_data, audio_length);
    fprintf(stderr, "whisper_bridge: whisper_full() returned: %d\n", result);

    // Debug: Check mel spectrogram length
    int n_len = whisper_n_len(ctx);
    fprintf(stderr, "whisper_bridge: mel spectrogram length (n_len) = %d\n", n_len);

    // Debug: Try language detection to verify encoder worked
    if (n_len > 0) {
        float lang_probs[100];
        int lang_id = whisper_lang_auto_detect(ctx, 0, 1, lang_probs);
        if (lang_id >= 0) {
            const char* lang_str = whisper_lang_str(lang_id);
            fprintf(stderr, "whisper_bridge: detected language: %s (id=%d, prob=%.3f)\n",
                    lang_str ? lang_str : "unknown", lang_id, lang_probs[lang_id]);
        } else {
            fprintf(stderr, "whisper_bridge: language detection failed: %d\n", lang_id);
        }
    }

    if (result != 0) {
        fprintf(stderr, "whisper_full failed with result: %d\n", result);
        char error_msg[100];
        snprintf(error_msg, sizeof(error_msg), "[DEBUG:whisper_full_failed:%d]", result);
        char* result_str = (char*)malloc(strlen(error_msg) + 1);
        if (result_str) strcpy(result_str, error_msg);
        return result_str;
    }

    // Collect all segments into single string
    const int n_segments = whisper_full_n_segments(ctx);
    fprintf(stderr, "whisper_bridge: n_segments = %d\n", n_segments);

    // Check if context has state
    if (ctx == nullptr) {
        fprintf(stderr, "whisper_bridge: ERROR - ctx is null after whisper_full\n");
    }

    // If no segments, return diagnostic string
    if (n_segments == 0) {
        const char* debug_msg = "[DEBUG:n_segments=0]";
        char* result = (char*)malloc(strlen(debug_msg) + 1);
        if (result) {
            strcpy(result, debug_msg);
        }
        return result;
    }

    // Debug: Check no_speech probability for each segment
    for (int i = 0; i < n_segments; i++) {
        float no_speech_prob = whisper_full_get_segment_no_speech_prob(ctx, i);
        fprintf(stderr, "whisper_bridge: segment %d no_speech_prob = %.3f\n", i, no_speech_prob);
    }

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
            fprintf(stderr, "whisper_bridge: segment %d: '%s'\n", i, text);
            strcat(result_text, text);
        }
    }

    fprintf(stderr, "whisper_bridge: final result (length %zu): '%s'\n", strlen(result_text), result_text);
    return result_text;
}

bool whisper_bridge_is_valid(whisper_context* ctx) {
    return ctx != nullptr;
}

} // extern "C"
