{ ... }:

{
  # Best default for RX 570 4GB: dense 4B, Q4_K_M stays in VRAM at 4K ctx.
  # Qwen3-4B is the quality/VRAM sweet spot on this generation; 8B Q4 spills to GTT.
  homeServer.ai.models.available.qwen = {
    displayName = "Qwen3-4B Q4_K_M";
    file = "Qwen3-4B-Q4_K_M.gguf";
    url = "https://huggingface.co/Qwen/Qwen3-4B-GGUF/resolve/main/Qwen3-4B-Q4_K_M.gguf";
    notes = ''
      ~2.5 GB weights. 4K context stays in 4 GB VRAM; 8K starts using GTT.
      Official Qwen GGUF, K-quant (IQ quants are slower on Vulkan).
    '';
  };
}
