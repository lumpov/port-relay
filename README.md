# Port Relay

TCP и UDP relay: входящий порт → исходящий хост:порт.

## What is This?

Прозрачный relay: клиент подключается к локальному порту, трафик пересылается на заданный хост:порт. TCP — через socat, UDP — через iptables NAT. Трафик 1:1 без изменений.

## Architecture

```
Clients
│
├─ Relay 1 (TCP)  →  :50025  →  btc.trustpool.cc:25
├─ Relay 2 (TCP)  →  :50443  →  btc.trustpool.cc:443
├─ Relay 3 (TCP)  →  :53333  →  btc.trustpool.cc:3333
├─ Relay 4 (UDP)  →  :51820  →  vpn.example.com:51820
│
↓
TCP: port-relay (socat)
UDP: iptables NAT (netfilter-persistent, сохраняется при перезагрузке)
```

## How It Works

1. Клиент подключается к relay на локальный порт
2. TCP: socat пересылает на заданный хост:порт
3. UDP: iptables DNAT/SNAT пересылает трафик (ядро)
4. Трафик 1:1 без изменений

## Quick Start

### Step 1: Clone/Copy Project

```bash
git clone <repo> mining-proxy
cd mining-proxy
```

### Step 2: Configure

Создать .env из .env.example, при необходимости отредактировать:

```bash
cp .env.example .env
nano .env
```

### Step 3: Install

```bash
sudo ./install
```

- Устанавливает зависимости (socat, iptables, etc)
- Настраивает sysctl (BBR, буферы, tcp_slow_start_after_idle, nf_conntrack)
- Применяет conntrack INVALID DROP
- Настраивает iptables (firewall, UDP NAT)
- Создаёт systemd сервис port-relay
- Сохраняет правила через netfilter-persistent (восстановление при перезагрузке)

### Step 4: Verify Service

```bash
systemctl status port-relay
```

### Step 5: Подключение к relay

Подключаться к RELAY_IP:входящий_порт (см. вывод install).

### Step 6: Monitor

```bash
./monitor
```

## Files Structure

```
mining-proxy/
├── .env              # Configuration
├── lib/
│   └── relay-config  # Parser, firewall, NAT helpers
├── relay             # TCP relay (socat)
├── monitor           # Real-time monitoring
├── install           # Installation script
├── uninstall         # Uninstall script
├── env-setup         # Sync .env with .env.example
├── logs/             # Relay logs
└── README.md
```

## Configuration (.env)

Формат RELAY_N: входящий_порт;исходящий_порт;исходящий_хост;TCP|UDP

```
RELAY_1="50025;25;btc.trustpool.cc;TCP"
RELAY_2="50443;443;btc.trustpool.cc;TCP"
RELAY_3="53333;3333;btc.trustpool.cc;TCP"
RELAY_4="51820;51820;vpn.example.com;UDP"

CONNECT_TIMEOUT=15
KEEPALIVE_IDLE=30
KEEPALIVE_INTVL=10
KEEPALIVE_CNT=3

ENABLE_LOGGING="y"
ENABLE_HEALTH_CHECK="y"
HEALTH_CHECK_TIMEOUT=10
HEALTH_CHECK_RETRIES=3
```

CONNECT_TIMEOUT, KEEPALIVE_* — для TCP (socat).

### Изменение конфигурации

Редактировать .env, перезапустить install или relay:

```bash
sudo ./install
```

Или только relay (для TCP; для UDP — нужен install, т.к. правила iptables):

```bash
sudo systemctl restart port-relay
```

При изменении UDP relay — запустить install заново.

## Port Mapping

```
Connect To (relay)      Protocol   Relay Forwards To
relay_ip:50025      →   TCP   →    btc.trustpool.cc:25
relay_ip:50443      →   TCP   →    btc.trustpool.cc:443
relay_ip:53333      →   TCP   →    btc.trustpool.cc:3333
relay_ip:51820      →   UDP   →    vpn.example.com:51820
```

## Systemd Service

Сервис: port-relay. TCP relay (socat) управляется systemd. UDP — через iptables, сохраняется netfilter-persistent.

```bash
systemctl status port-relay
systemctl restart port-relay
journalctl -u port-relay -f
```

## Logging

logs/relay.log (TCP relay)

```bash
tail -f logs/relay.log
```

## Troubleshooting

### Service Won't Start

```bash
sudo systemctl status port-relay
sudo journalctl -u port-relay -n 100
```

### Relay Not Forwarding TCP

```bash
ss -tlnp | grep socat
tail -50 logs/relay.log
```

### Relay Not Forwarding UDP

Проверить правила NAT:

```bash
iptables -t nat -L PREROUTING -n -v
```

### Firewall / Security Groups

Открыть порты relay в cloud Security Groups и/или ufw.

## Performance

### Sysctl (/etc/sysctl.d/99-port-relay.conf)

- BBR, fq, ip_forward
- Буферы 16MB
- tcp_keepalive
- tcp_slow_start_after_idle=0
- nf_conntrack_tcp_timeout_established=86400
- MTU probing, SACK, window scaling

### Security

- conntrack INVALID DROP (INPUT, OUTPUT, FORWARD)

## Uninstall

```bash
sudo ./uninstall
```

Останавливает сервис, удаляет unit, sysctl, firewall и NAT правила.

## Features

- TCP relay (socat), UDP relay (iptables NAT)
- Формат: in_port;out_port;out_host;TCP|UDP
- netfilter-persistent — восстановление правил при перезагрузке
- BBR, буферы, keepalive для нестабильных каналов
- conntrack INVALID DROP

## System Requirements

OS: Debian 11, 12 or Ubuntu 22, 24
Root для install
~100MB disk, <50MB RAM

## License

MIT
