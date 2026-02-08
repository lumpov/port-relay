# Port Relay

TCP relay: входящий порт → исходящий хост:порт.

## What is This?

Прозрачный TCP relay: клиент подключается к локальному порту, трафик пересылается на заданный хост:порт. Трафик 1:1 без изменений.

## Architecture

```
Clients
│
├─ Relay 1  →  :50025  →  btc.trustpool.cc:25
├─ Relay 2  →  :50443  →  btc.trustpool.cc:443
├─ Relay 3  →  :53333  →  btc.trustpool.cc:3333
│
↓
port-relay (socat TCP forwarding)
```

## How It Works

1. Клиент подключается к relay на локальный порт (например :53333)
2. Relay пересылает на заданный хост:порт
3. Трафик 1:1 без изменений
4. Relay держит соединение с целевым хостом при отключении клиента

## Quick Start

### Step 1: Clone/Copy Project

```bash
git clone <repo> mining-proxy
cd mining-proxy
```

### Step 2: Configure (Optional)

Default .env already configured for btc.trustpool.cc

Edit if needed:

```bash
nano .env
```

### Step 3: Install

```bash
sudo ./install
```

This will:
- Install dependencies (socat, etc)
- Configure kernel parameters (TCP optimization)
- Create systemd service port-relay
- Create logs/ directory
- Start the relay service

### Step 4: Verify Service is Running

```bash
systemctl status port-relay
```

Expected: active (running)

### Step 5: Подключение к relay

Подключаться к RELAY_IP:входящий_порт для каждого relay (см. вывод install). Узнать IP:

```bash
hostname -I
```

### Step 6: Monitor Relay

Real-time status:

```bash
./monitor
```

Shows:
- Outbound connectivity (UP/DOWN)
- Service status
- Connections per relay
- Recent logs

## Files Structure

```
mining-proxy/
├── .env              # Configuration
├── relay             # TCP relay application
├── monitor           # Real-time monitoring
├── install           # Installation script
├── uninstall         # Uninstall script
├── logs/             # Relay logs
└── README.md         # This file
```

## Configuration (.env)

Формат RELAY_N: входящий_порт,исходящий_порт,исходящий_хост. Количество RELAY_* неограничено.

```
RELAY_1="50025,25,btc.trustpool.cc"
RELAY_2="50443,443,btc.trustpool.cc"
RELAY_3="53333,3333,btc.trustpool.cc"

CONNECT_TIMEOUT=15
KEEPALIVE_IDLE=30
KEEPALIVE_INTVL=10
KEEPALIVE_CNT=3

ENABLE_LOGGING="y"
ENABLE_HEALTH_CHECK="n"
```

Опционально: CONNECT_TIMEOUT — таймаут подключения к целевому хосту (сек). KEEPALIVE_* — параметры TCP keepalive на сокетах (для нестабильных каналов: меньше KEEPALIVE_IDLE — быстрее обнаружение обрыва). По умолчанию используются значения выше, если переменные не заданы.

Пример разных хостов:

```
RELAY_1="50025,25,btc.trustpool.cc"
RELAY_2="443,443,yandex.ru"
RELAY_3="50443,50443,y.lumpov.ru"
```

### Изменение конфигурации

Редактировать .env и перезапустить:

```bash
sudo systemctl restart port-relay
```

## Port Mapping

```
Connect To (relay)      Relay Forwards To
relay_ip:50025      →    btc.trustpool.cc:25
relay_ip:50443      →    btc.trustpool.cc:443
relay_ip:53333      →    btc.trustpool.cc:3333
```

## Systemd Service

Сервис systemd: port-relay. Создаётся скриптом install.

### Commands

Check status:

```bash
systemctl status port-relay
```

View logs:

```bash
journalctl -u port-relay -n 50 -f
```

Start service:

```bash
systemctl start port-relay
```

Stop service:

```bash
systemctl stop port-relay
```

Restart service:

```bash
systemctl restart port-relay
```

## Logging

### Relay Logs

Location: logs/relay.log (in project directory)

View:

```bash
tail -f logs/relay.log
```

Example output:

```
[2024-01-15 10:05:30] Port Relay Started
[2024-01-15 10:05:30] Port mapping:
[2024-01-15 10:05:30]   Local :50025 → btc.trustpool.cc:25
[2024-01-15 10:05:30] Starting relay instances...
[2024-01-15 10:05:30] Relay started (PID: 12345)
[2024-01-15 10:05:32] Connection from 192.168.1.100:45234
```

### Systemd Logs

View:

```bash
journalctl -u port-relay -f
```

### Disable Logging

In .env:

```
ENABLE_LOGGING="n"
```

## Monitoring

### Real-time Monitor

```bash
./monitor
```

Updates every 5 seconds. Shows:
- Outbound connectivity (UP/DOWN for each relay)
- Service status (RUNNING/STOPPED)
- Connections per relay
- Last 5 log entries

### Check Connections

Current connections:

```bash
ss -tn | grep :50
```

## Troubleshooting

### Service Won't Start

Check status:

```bash
sudo systemctl status port-relay
```

View error details:

```bash
sudo journalctl -u port-relay -n 100
```

Common issues:
- Port already in use
- Permission denied (use sudo)
- .env file missing

### Can't Connect to Target

Test target connectivity:

```bash
nc -zv btc.trustpool.cc 25
nc -zv btc.trustpool.cc 443
nc -zv btc.trustpool.cc 3333
```

If all fail: Check internet connection
If some fail: Target ports might be down

### Relay Not Forwarding Traffic

Check relay is listening:

```bash
ss -tlnp | grep socat
```

Expected: socat processes listening on ports 50025, 50443, 53333

Check relay logs:

```bash
tail -50 logs/relay.log
```

### No Connections

Check relay is listening on correct ports:

```bash
netstat -tlnp | grep -E "(50025|50443|53333)"
```

Check client is connecting to relay IP:

```bash
telnet RELAY_IP 53333
```

Should connect. If not, firewall might be blocking.

### High Latency

Check latency:

```bash
ping btc.trustpool.cc
```

Check for packet loss:

```bash
ping -c 100 btc.trustpool.cc
```

Some loss (>5%) = connection unstable

### Firewall Issues

Allow relay ports:

```bash
sudo ufw allow 50025
sudo ufw allow 50443
sudo ufw allow 53333
```

## Performance

### Kernel Optimizations

Configured by install in /etc/sysctl.d/99-port-relay.conf:

- BBR TCP congestion control
- Large buffers (16MB)
- TCP keep-alive (sysctl)
- Window scaling
- SACK (Selective acknowledgment)
- MTU probing (prevents fragmentation)

### Relay (socat)

На сокетах включены keepalive и таймаут подключения к целевому хосту (CONNECT_TIMEOUT, KEEPALIVE_* в .env). Ускоряют обнаружение мёртвых соединений на нестабильных каналах.

## Advanced Usage

### Multiple Hosts

Каждая RELAY_* может указывать на свой хост. Пример:

```
RELAY_1="50025,25,btc.trustpool.cc"
RELAY_2="50443,443,y.lumpov.ru"
RELAY_3="443,443,yandex.ru"
```

Для изменения конфигурации редактировать .env и перезапустить сервис.

### Custom Ports

Edit .env (format: incoming_port,outgoing_port,outgoing_host):

```
RELAY_1="9001,25,btc.trustpool.cc"
RELAY_2="9002,443,btc.trustpool.cc"
```

Restart:

```bash
sudo systemctl restart port-relay
```

## Maintenance

### Regular Checks

Check service is running:

```bash
systemctl status port-relay
```

Check for errors:

```bash
journalctl -u port-relay -p err
```

Monitor connections:

```bash
./monitor
```

### Updates

1. Update files (relay, monitor, etc)
2. Restart service:

```bash
sudo systemctl restart port-relay
```

### Uninstall

```bash
sudo ./uninstall
```

Останавливает сервис, удаляет unit и sysctl. Файлы проекта не удаляются. Удалить каталог при необходимости вручную.

## Security Notes

- Relay is transparent TCP forwarder - no encryption
- Use VPN if you need encryption for traffic
- Relay runs as root (required for low ports)
- Firewall ports if relay server is exposed to internet

## System Requirements

OS: Debian 11, 12 or Ubuntu 22, 24
Privileges: Root (for install)
Disk space: ~100MB
Memory: <50MB
Network: TCP connectivity to target hosts

## Features

Supported:
- Transparent TCP relay (1:1 forwarding)
- Multiple port mapping (3 independent relays)
- Real-time monitoring
- Connection logging
- Health checks (optional)
- Systemd service
- BBR TCP congestion control
- Large buffers for packet loss
- TCP keep-alive for unstable networks
- Automatic restart on crash
- Transparent forwarding (no protocol modification)

Not supported:
- Job caching
- Share manipulation
- Difficulty adaptation
- Protocol understanding
- Load balancing

## Support

Check logs:

```bash
tail -f logs/relay.log
journalctl -u port-relay -f
```

Common issues in Troubleshooting section above.

## License

MIT

---

Created: 2024
Version: 1.0
Last Updated: 2024-01-15