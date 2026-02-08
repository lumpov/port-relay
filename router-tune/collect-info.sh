#!/bin/bash
# Сбор информации о PC-маршрутизаторе (Fedora) для анализа и подбора настроек.
# Запуск: ./collect-info.sh   Вывод — в консоль, пришлите результат.

set -e

echo "========== HOST & OS =========="
echo "Date: $(date -Iseconds)"
echo "Hostname: $(hostname)"
uname -a
echo
[[ -f /etc/os-release ]] && cat /etc/os-release
echo

echo "========== DEFAULT ROUTE & WAN INTERFACE =========="
ip route show default
WAN_IF=$(ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}')
echo "Detected WAN interface: ${WAN_IF:-<none>}"
echo

echo "========== INTERFACES (ip link) =========="
ip -br link show
echo
ip link show
echo

echo "========== ADDRESSES (ip addr) =========="
ip -br addr show
echo

echo "========== ROUTING TABLE =========="
ip route show
echo

echo "========== QDISC (tc) PER INTERFACE =========="
for if in $(ip -o link show | awk -F': ' '{print $2}' | sed 's/@.*//'); do
  echo "--- $if ---"
  tc qdisc show dev "$if" 2>/dev/null || echo "(none or no permission)"
done
echo

echo "========== IPTABLES MANGLE (FORWARD) =========="
iptables -t mangle -L FORWARD -n -v 2>/dev/null || echo "(need root or no iptables)"
echo

echo "========== FIREWALLD (if active) =========="
if command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
  firewall-cmd --state 2>/dev/null
  firewall-cmd --list-all 2>/dev/null || true
  echo "Direct passthrough (raw):"
  firewall-cmd --direct --get-all-passthroughs 2>/dev/null || true
  firewall-cmd --permanent --direct --get-all-passthroughs 2>/dev/null || true
else
  echo "firewalld not active or not installed"
fi
echo

echo "========== SYSCTL (relevant) =========="
for k in net.ipv4.ip_forward net.core.rmem_max net.core.wmem_max \
  net.ipv4.tcp_rmem net.ipv4.tcp_wmem net.ipv4.tcp_mtu_probing \
  net.ipv4.tcp_sack net.core.default_qdisc net.ipv4.tcp_congestion_control \
  net.netfilter.nf_conntrack_max net.core.somaxconn; do
  v=$(sysctl -n "$k" 2>/dev/null) && echo "$k=$v" || true
done
echo

echo "========== KERNEL MODULES (qdisc, conntrack) =========="
lsmod 2>/dev/null | grep -E '^sch_|^nf_conntrack|^xt_|^nf_nat' || echo "(none or no permission)"
echo

echo "========== CONNTRACK (if present) =========="
if command -v conntrack &>/dev/null; then
  conntrack -S 2>/dev/null || true
elif [[ -f /proc/net/nf_conntrack ]]; then
  echo "nf_conntrack entries: $(wc -l < /proc/net/nf_conntrack 2>/dev/null || echo 0)"
fi
echo

echo "========== PPP / MODEM (if present) =========="
ip link show type ppp 2>/dev/null || true
for p in /sys/class/net/ppp*; do
  [[ -d "$p" ]] && echo "PPP: $p" && cat "$p/mtu" 2>/dev/null && true
done
ls /sys/class/net/ 2>/dev/null | grep -E 'ppp|wwan|usb' || true
echo

echo "========== END =========="
