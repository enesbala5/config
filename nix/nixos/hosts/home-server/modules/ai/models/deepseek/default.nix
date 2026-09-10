{ ... }:

{
  # Optional reasoning distill. Small enough to leave VRAM headroom, but
  # not a general chat replacement for Qwen3-4B.
  homeServer.ai.models.available.deepseek = {
    displayName = "DeepSeek-R1-Distill-Qwen-1.5B Q4_K_M";
    file = "DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf";
    url = "https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf";
    notes = ''
      ~1.1 GB weights. Easy VRAM fit. Distilled reasoner — better as a
      specialist than as the Hermes daily driver.
    '';
  };
}
