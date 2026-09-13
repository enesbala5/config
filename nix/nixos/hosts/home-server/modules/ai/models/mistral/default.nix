{ ... }:

{
  # Optional. 7B Q4 is larger than the 4 GB working set and will GTT-spill.
  # Leave disabled unless you want to measure the quality vs speed tradeoff.
  homeServer.ai.models.available.mistral = {
    displayName = "Mistral-7B-Instruct-v0.3 Q4_K_M";
    file = "Mistral-7B-Instruct-v0.3-Q4_K_M.gguf";
    url = "https://huggingface.co/bartowski/Mistral-7B-Instruct-v0.3-GGUF/resolve/main/Mistral-7B-Instruct-v0.3-Q4_K_M.gguf";
    notes = ''
      ~4.4 GB weights — will overflow 4 GB VRAM into GTT. Usable, not the
      default. Prefer qwen unless you specifically want Mistral instruct.
    '';
  };
}
