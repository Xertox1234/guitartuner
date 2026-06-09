#!/bin/bash
# Maps a LUMA Swift file path to one or more domain labels.
# Usage: source lib/domain-map.sh; get_domains "/absolute/path/to/File.swift"
# Prints one domain label per line on stdout.

get_domains() {
  local path="$1"

  # dsp — signal processing core
  if [[ "$path" == */DSP/* ]] || \
     [[ "$path" == *Autocorrelation* ]] || \
     [[ "$path" == *FrequencyInterpolator* ]] || \
     [[ "$path" == *PitchDetector* ]] || \
     [[ "$path" == *Preprocess.swift ]] || \
     [[ "$path" == *Smoothing.swift ]] || \
     [[ "$path" == *SpectralAnalyzer* ]] || \
     [[ "$path" == *StrobePhase.swift ]] || \
     [[ "$path" == *AnalysisConfig* ]] || \
     [[ "$path" == */Bench/* ]] || \
     [[ "$path" == *Benchmark* ]] || \
     [[ "$path" == *Note.swift ]] || \
     [[ "$path" == *PitchReading* ]]; then
    echo "dsp"
  fi

  # capture — audio I/O via AVAudioEngine
  if [[ "$path" == */Capture/* ]] || \
     [[ "$path" == *AudioCapture* ]] || \
     [[ "$path" == *MicrophonePermission* ]] || \
     [[ "$path" == *TunerEngineError* ]]; then
    echo "capture"
  fi

  # pipeline — real-time sample path and public actor
  if [[ "$path" == */Pipeline/* ]] || \
     [[ "$path" == *RingBuffer* ]] || \
     [[ "$path" == *PitchPipeline* ]] || \
     [[ "$path" == *TunerEngine.swift ]] || \
     [[ "$path" == *ToneSynth* ]]; then
    echo "pipeline"
  fi

  # strobe — Metal rendering layer
  if [[ "$path" == */Strobe/* ]] || \
     [[ "$path" == *MetalStrobe* ]] || \
     [[ "$path" == *AuroraStrobe* ]] || \
     [[ "$path" == *RadialStrobe* ]] || \
     [[ "$path" == *ReducedGauge* ]] || \
     [[ "$path" == *StrobeMath* ]] || \
     [[ "$path" == *StrobeField* ]] || \
     [[ "$path" == *StrobeLab* ]] || \
     [[ "$path" == *StrobePalette* ]] || \
     [[ "$path" == *StrobeStyle* ]] || \
     [[ "$path" == *StrobeInput* ]] || \
     [[ "$path" == *MenuBarStrobe* ]] || \
     [[ "$path" == *StrobeShader* ]]; then
    echo "strobe"
  fi

  # swiftui — app layer views and models
  if [[ "$path" == */App/*.swift ]] || \
     [[ "$path" == */App/Engine/* ]] || \
     [[ "$path" == *LiveTunerScreen* ]] || \
     [[ "$path" == *LiveTunerModel* ]] || \
     [[ "$path" == *LumaApp.swift ]] || \
     [[ "$path" == *RootView* ]] || \
     [[ "$path" == *SettingsView* ]] || \
     [[ "$path" == *MenuBarTuner* ]]; then
    echo "swiftui"
  fi

  # design-system — tokens, components, model, modifiers
  if [[ "$path" == */Tokens/* ]] || \
     [[ "$path" == */Components/* ]] || \
     [[ "$path" == */Modifiers/* ]] || \
     [[ "$path" == */Gallery/* ]] || \
     [[ "$path" == *LumaColor* ]] || \
     [[ "$path" == *LumaFont* ]] || \
     [[ "$path" == *LumaFonts* ]] || \
     [[ "$path" == *LumaMusic* ]] || \
     [[ "$path" == *TunerVisualState* ]] || \
     [[ "$path" == *Tuning.swift ]] || \
     [[ "$path" == *Bloom.swift ]] || \
     [[ "$path" == *FieldWash* ]] || \
     [[ "$path" == *ScreenChrome* ]]; then
    echo "design-system"
  fi

  # testing
  if [[ "$path" == *Tests/* ]] || \
     [[ "$path" == *Test.swift ]] || \
     [[ "$path" == *Tests.swift ]]; then
    echo "testing"
  fi
}

# Priority — lower number = higher priority = fills context budget first on spill
domain_rank() {
  case "$1" in
    dsp)           echo 10 ;;
    capture)       echo 20 ;;
    pipeline)      echo 30 ;;
    strobe)        echo 40 ;;
    swiftui)       echo 50 ;;
    design-system) echo 60 ;;
    testing)       echo 70 ;;
    *)             echo 99 ;;
  esac
}
