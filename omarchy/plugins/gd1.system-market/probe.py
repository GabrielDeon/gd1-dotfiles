import json
import math
from pathlib import Path
import sys
import time
import urllib.request


def read(path):
    try:
        return Path(path).read_text().strip()
    except OSError:
        return ''


def number(value, low, high):
    try:
        n = float(value)
        return n if math.isfinite(n) and low <= n <= high else None
    except (ValueError, TypeError):
        return None


def cpu():
    ticks = list(map(int, read('/proc/stat').splitlines()[0].split()[1:9]))
    return sum(ticks), ticks[3] + ticks[4]


def hardware():
    a, idle_a = cpu()
    time.sleep(0.3)
    b, idle_b = cpu()
    memory = {}
    for line in read('/proc/meminfo').splitlines():
        key, value = line.split(':', 1)
        memory[key] = int(value.strip().split()[0])
    result = {'cpu': round(100 * (1 - (idle_b-idle_a)/(b-a)), 1) if b > a else None,
              'ram': round(100 * (1-memory['MemAvailable']/memory['MemTotal']), 1),
              'cpuTemp': None, 'gpu': None, 'gpuTemp': None}
    for hw in sorted(Path('/sys/class/hwmon').glob('hwmon*')):
        if read(hw/'name') in ('k10temp', 'coretemp', 'zenpower'):
            temps = [number(read(p), -20000, 150000) for p in hw.glob('temp*_input')]
            temps = [t/1000 for t in temps if t is not None]
            if temps:
                result['cpuTemp'] = max(temps)
    for device in sorted(Path('/sys/class/drm').glob('card[0-9]*/device')):
        busy = number(read(device/'gpu_busy_percent'), 0, 100)
        if busy is not None:
            result['gpu'] = busy
            temps = list(device.glob('hwmon/hwmon*/temp1_input'))
            if temps:
                temp = number(read(temps[0]), -20000, 150000)
                result['gpuTemp'] = temp/1000 if temp is not None else None
            break
    return result


def parse_quotes(data, now=None):
    now = time.time() if now is None else now
    result = {}
    for key, out, base, quote, maximum in [('BTCUSD','btc','BTC','USD',1e9), ('USDBRL','usd','USD','BRL',1000)]:
        row = data[key]
        if row['code'] != base or row['codein'] != quote:
            raise ValueError('Unexpected currency')
        price = number(row.get('bid'), 0.000001, maximum)
        stamp = number(row.get('timestamp'), 1, now+300)
        if price is None or stamp is None:
            raise ValueError('Invalid quote')
        result[out] = price
        result[out+'Time'] = stamp * 1000
    return result


def markets():
    requested_at = int(time.time() * 1000)
    request = urllib.request.Request('https://economia.awesomeapi.com.br/json/last/BTC-USD,USD-BRL', headers={'User-Agent':'Omarchy-System-Market/1.0', 'Cache-Control':'no-cache', 'Pragma':'no-cache'})
    # No redirects: the plugin only contacts the documented HTTPS source.
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *args, **kwargs):
            return None
    with urllib.request.build_opener(NoRedirect).open(request, timeout=10) as response:
        raw = response.read(32769)
    if len(raw) > 32768:
        raise ValueError('Response too large')
    result = parse_quotes(json.loads(raw))
    result['requestedAt'] = requested_at
    return result


if __name__ == '__main__':
    try:
        print(json.dumps(markets() if sys.argv[1:] == ['markets'] else hardware(), allow_nan=False))
    except Exception:
        print(json.dumps({'error': True}))
