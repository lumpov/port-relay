# Настройка PC-маршрутизатора (Fedora) для майнера через 3G/GPRS/EDGE

Два скрипта для машины с Linux (Fedora), которая раздаёт интернет майнеру через модем.

## 1. collect-info.sh — сбор диагностики

Запуск без root (часть данных будет неполной без root):

```bash
./collect-info.sh
```

Вывод в консоль. Результат можно сохранить и отправить для анализа:

```bash
./collect-info.sh 2>&1 | tee router-info.txt
```

## 2. apply-tune.sh — применение настроек

- **MSS clamping** для проходящего трафика (меньше фрагментации на медленном канале).
- **fq_codel** на WAN-интерфейсе (без жёсткого лимита скорости — подходит при разной связи).
- Минимальный **sysctl** (ip_forward, буферы, tcp_mtu_probing).

Запуск (нужен root):

```bash
sudo ./apply-tune.sh
```

WAN-интерфейс берётся из default route. Или явно:

```bash
sudo ./apply-tune.sh ppp0
# или
sudo WAN_IF=ppp0 ./apply-tune.sh
```

После переподключения модема (down/up интерфейса) qdisc сбрасывается — перезапустите скрипт или настройте его запуск при поднятии интерфейса (ppp hook, NetworkManager dispatcher, systemd path).
