#!/usr/bin/env bash
set -uo pipefail

echo "=== PCIe ASPM Verification ==="
echo ""

echo "1. Kernel Config Check:"
if [[ -f "/boot/config-$(uname -r)" ]]; then
  grep -i "CONFIG_PCIEASPM" "/boot/config-$(uname -r)" || echo "  CONFIG_PCIEASPM not found in /boot/config-$(uname -r)"
else
  echo "  /boot/config-$(uname -r) not found"
fi

if [[ -f "/proc/config.gz" ]]; then
  zcat /proc/config.gz 2>/dev/null | grep -i "CONFIG_PCIEASPM" || echo "  ASPM config not found in /proc/config.gz"
fi
echo ""

echo "2. Current ASPM Policy:"
find /sys/devices -name aspm 2>/dev/null | while read -r aspm_file; do
  echo "  $aspm_file: $(cat "$aspm_file" 2>/dev/null || echo 'N/A')"
done
echo ""

echo "3. PCIe Device Power Management Capabilities:"
lspci -vv 2>/dev/null | grep -A 5 -i "l1.*l0s" | head -20 || echo "  No L1/L0s states found"
echo ""

echo "4. Kernel Messages (ASPM):"
dmesg | grep -i aspm | tail -10 || echo "  No ASPM messages in dmesg"
echo ""

echo "5. Power States (if powertop available):"
if command -v powertop >/dev/null 2>&1; then
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  echo "  Running powertop analysis..."
    powertop --html=/tmp/powertop-aspm-check.html 2>/dev/null && \
    echo "  Report saved to /tmp/powertop-aspm-check.html" || \
      echo "  powertop run failed (check permissions)"
  echo "  Check the HTML file for PCIe device power states"
  else
    echo "  powertop requires root; rerun with sudo to generate the report"
  fi
else
  echo "  powertop not installed - install with: nix-env -iA nixos.powertop"
fi
echo ""

echo "6. Kernel Parameters:"
if grep -q "pcie_aspm" /proc/cmdline 2>/dev/null; then
  echo "  ASPM parameters found in kernel cmdline:"
  grep -o "pcie_aspm[^ ]*" /proc/cmdline
else
  echo "  No ASPM parameters in kernel cmdline"
  echo "  Consider adding: pcie_aspm=force or pcie_aspm.policy=powersave"
fi
echo ""

echo "=== Summary ==="
echo "If ASPM is not working:"
echo "  1. Add kernel parameter: pcie_aspm=force"
echo "  2. Or: pcie_aspm.policy=powersave"
echo "  3. Check BIOS/UEFI settings for ASPM"
echo "  4. Some devices may not support ASPM"

