{ ... }:

{
  # mlabonne's abliteration of the original Qwen3-4B, quantized by
  # mradermacher. Same ~2.5 GB Q4_K_M footprint as the stock dense build, so
  # VRAM and KV budgets carry over unchanged.
  homeServer.ai.models.available.qwen-abliterated = {
    displayName = "Qwen3-4B abliterated Q4_K_M";
    file = "Qwen3-4B-abliterated.Q4_K_M.gguf";
    url = "https://huggingface.co/mradermacher/Qwen3-4B-abliterated-GGUF/resolve/main/Qwen3-4B-abliterated.Q4_K_M.gguf";
    notes = ''
      2497280704 bytes. Abliterated from the hybrid Qwen3-4B, not the 2507
      Instruct merge: the GGUF keeps tokenizer.chat_template with
      enable_thinking, so thinking still works. Refusal behaviour is largely
      gone; expect a small instruction-following and tool-calling cost against
      stock Qwen3-4B.
    '';
  };
}
