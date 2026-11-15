{ ... }:

{
  # Dense 4B Q4_K_M weights; context residency also depends on KV cache type.
  # Qwen3-4B is the quality/VRAM sweet spot on this generation; 8B Q4 spills to GTT.
  homeServer.ai.models.available.qwen = {
    displayName = "Qwen3-4B Q4_K_M";
    file = "Qwen3-4B-Q4_K_M.gguf";
    url = "https://huggingface.co/Qwen/Qwen3-4B-GGUF/resolve/main/Qwen3-4B-Q4_K_M.gguf";
    notes = ''
      ~2.5 GB weights. 16K/q4_0 KV targets the footprint of 8K/q8_0.
      Verify Vulkan support, VRAM residency and long-context quality after deployment.
      Official Qwen GGUF, K-quant (IQ quants are slower on Vulkan).
    '';
  };
}
