<?php
// Humans only (the owner's call): every page goes through here first.
// A visitor that looks like a bot (a bot's User-Agent, no browser headers,
// too many requests a minute, or a cloud / hosting / scanner network) gets
// an "I'm not a robot" page instead. Ticking it either runs Cloudflare
// Turnstile (when wishlist-config.php has `turnstile_site_key` and
// `turnstile_secret`) or Sidekick's own check: the browser works out a
// small proof-of-work puzzle (about a second), which scripts that don't
// run a real browser can't. Passing gives a signed cookie (`sk_human`, 30
// days, for this browser only), so a person is asked at most once a month.
//
// index.php calls human_gate(); .htaccess sends /preview and /privacy
// here (?page=…), and the tick posts here (?verify).

declare(strict_types=1);

if (!defined('WISHLIST_LIB')) {
    define('WISHLIST_LIB', true);
    require __DIR__ . '/wishlist.php';
}

const GATE_COOKIE = 'sk_human';
const GATE_DAYS = 30;
const GATE_BITS = 18;          // puzzle size: about a second in a phone's browser
const GATE_PER_MINUTE = 40;    // requests a minute from one address before it's asked

/** A secret made once on the hosting, for signing the cookie. */
function gate_key(): string {
    $file = data_dir() . '/gate.key';
    $key = @file_get_contents($file);
    if (!is_string($key) || strlen($key) < 32) {
        $key = random_bytes(32);
        @file_put_contents($file, $key, LOCK_EX);
        @chmod($file, 0600);
    }
    return $key;
}

function gate_config(): array {
    $file = __DIR__ . '/wishlist-config.php';
    $c = is_readable($file) ? include $file : [];
    return is_array($c) ? $c : [];
}

/** The browser this cookie belongs to (a cookie copied elsewhere fails). */
function gate_browser(): string {
    return substr(hash('sha256', (string)($_SERVER['HTTP_USER_AGENT'] ?? '')), 0, 16);
}

function gate_sign(string $data): string {
    return hash_hmac('sha256', $data, gate_key());
}

function gate_passed(): bool {
    $c = (string)($_COOKIE[GATE_COOKIE] ?? '');
    if (!preg_match('/^(\d{10})\.([0-9a-f]{64})$/', $c, $m)) return false;
    if ((int)$m[1] < time()) return false;
    return hash_equals(gate_sign($m[1] . '|' . gate_browser()), $m[2]);
}

function gate_give_cookie(): void {
    $until = (string)(time() + GATE_DAYS * 86400);
    setcookie(GATE_COOKIE, $until . '.' . gate_sign($until . '|' . gate_browser()), [
        'expires' => (int)$until,
        'path' => '/',
        'secure' => ($_SERVER['HTTPS'] ?? '') !== '' && ($_SERVER['HTTPS'] ?? '') !== 'off',
        'httponly' => true,
        'samesite' => 'Lax',
    ]);
}

/** Requests in the last minute from this address (hashed), counted. */
function gate_rate(): int {
    $who = substr(hash('sha256', (string)($_SERVER['REMOTE_ADDR'] ?? '')), 0, 16);
    $f = @fopen(data_dir() . '/gate-rate.json', 'c+');
    if (!$f) return 0;
    flock($f, LOCK_EX);
    $all = json_decode(stream_get_contents($f) ?: '', true);
    if (!is_array($all)) $all = [];
    $now = time();
    $mine = array_values(array_filter($all[$who] ?? [], fn($t) => $t > $now - 60));
    $mine[] = $now;
    $all[$who] = array_slice($mine, -100);
    // Forget addresses quiet for a minute.
    $all = array_filter($all, fn($ts) => max($ts) > $now - 60);
    ftruncate($f, 0);
    rewind($f);
    fwrite($f, json_encode($all));
    fflush($f);
    flock($f, LOCK_UN);
    fclose($f);
    return count($mine);
}

/** Whether this visitor looks like a bot (and so is asked). */
function gate_suspicious(): bool {
    $ua = (string)($_SERVER['HTTP_USER_AGENT'] ?? '');
    if (is_bot($ua)) return true;
    // Every real browser sends these with a page request.
    if (($_SERVER['HTTP_ACCEPT_LANGUAGE'] ?? '') === '') return true;
    if (!str_contains((string)($_SERVER['HTTP_ACCEPT'] ?? ''), 'text/html')) return true;
    if (gate_rate() > GATE_PER_MINUTE) return true;
    // A network already looked up (np7dpanel.php → Visits) that's a cloud,
    // hosting company or scanner: whatever browser it claims to be.
    $ip = (string)($_SERVER['REMOTE_ADDR'] ?? '');
    $places = json_decode((string)@file_get_contents(data_dir() . '/ip-places.json'), true);
    $network = is_array($places) ? (string)($places[$ip]['network'] ?? '') : '';
    return is_cloud_network($network);
}

/** Counts what the gate did today (np7dpanel.php → Visits). */
function gate_count(string $what): void {
    $file = data_dir() . '/gate.json';
    $f = @fopen($file, 'c+');
    if (!$f) return;
    flock($f, LOCK_EX);
    $data = json_decode(stream_get_contents($f) ?: '', true);
    if (!is_array($data)) $data = [];
    $day = gmdate('Y-m-d');
    $data[$day][$what] = ($data[$day][$what] ?? 0) + 1;
    ksort($data);
    $data = array_slice($data, -60, null, true);
    ftruncate($f, 0);
    rewind($f);
    fwrite($f, json_encode($data));
    fflush($f);
    flock($f, LOCK_UN);
    fclose($f);
}

/** Lets humans through; shows the check to anything that looks like a bot. */
function human_gate(string $back): void {
    if (gate_passed()) return;
    try {
        if (!gate_suspicious()) return;
    } catch (Throwable $e) {
        return;   // never lock people out because the check itself broke
    }
    gate_count('shown');
    gate_page($back);
    exit;
}

/** The puzzle: a random value, its time and a signature, so it can't be
 *  made up or used twice after it's old. */
function gate_puzzle(): string {
    $data = bin2hex(random_bytes(12)) . '.' . time();
    return $data . '.' . substr(gate_sign('puzzle|' . $data), 0, 32);
}

function gate_page(string $back, string $problem = ''): void {
    http_response_code(403);
    header('Content-Type: text/html; charset=utf-8');
    header('Cache-Control: no-store');
    header('X-Robots-Tag: noindex, nofollow');
    $config = gate_config();
    $site = (string)($config['turnstile_site_key'] ?? '');
    $puzzle = gate_puzzle();
    $e = fn(string $s) => htmlspecialchars($s, ENT_QUOTES);
    ?><!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow"><title>Just checking · Sidekick</title>
<link rel="icon" href="/website/icon-64.png">
<?php if ($site !== ''): ?><script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script><?php endif; ?>
<style>
:root{color-scheme:dark}*{box-sizing:border-box}
body{margin:0;min-height:100vh;display:grid;place-items:center;background:#121212;color:#f2f2f2;
font:16px/1.5 Inter,-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;padding:16px}
.card{width:100%;max-width:400px;background:#1c1c1c;border-radius:22px;padding:28px}
.logo{width:44px;height:44px;border-radius:12px;display:block;margin-bottom:18px}
h1{font-size:24px;margin:0 0 6px}p{margin:0 0 20px;color:#a1a1a6;font-size:14.5px}
.check{display:flex;align-items:center;gap:14px;width:100%;padding:16px 18px;border-radius:16px;
background:#262626;border:1px solid #ffffff1f;color:#f2f2f2;font:inherit;font-size:16px;cursor:pointer;text-align:left}
.box{flex:none;width:26px;height:26px;border-radius:8px;border:2px solid #8a8a8f;display:grid;place-items:center;transition:.2s}
.check[aria-checked=true] .box{background:#45d07e;border-color:#45d07e}
.spin{width:18px;height:18px;border-radius:50%;border:2.5px solid #ffffff33;border-top-color:#fff;animation:s .8s linear infinite}
@keyframes s{to{transform:rotate(360deg)}}
.err{color:#ff6b5e;font-size:14px;margin-top:14px}.small{font-size:12.5px;color:#8a8a8f;margin:18px 0 0}
</style></head><body>
<form class="card" method="post" action="/gate.php?verify" id="f">
  <img class="logo" src="/website/icon-192.png" alt="">
  <h1>Just checking</h1>
  <p>Sidekick's site is for people. Tick the box and you're in (once a month at most).</p>
  <input type="hidden" name="back" value="<?= $e($back) ?>">
  <input type="hidden" name="puzzle" value="<?= $e($puzzle) ?>">
  <input type="hidden" name="answer" id="answer">
  <input type="hidden" name="took" id="took">
<?php if ($site !== ''): ?>
  <div class="cf-turnstile" data-sitekey="<?= $e($site) ?>" data-theme="dark" data-callback="skDone"></div>
  <script>function skDone(){document.getElementById('f').submit()}</script>
<?php else: ?>
  <button type="button" class="check" id="c" role="checkbox" aria-checked="false"><span class="box" id="b"></span>I'm not a robot</button>
  <noscript><p class="err">This check needs JavaScript. Turn it on and reload the page.</p></noscript>
  <script>
  (()=>{const c=document.getElementById('c'),b=document.getElementById('b'),start=performance.now();let busy=false;
  const zeros=(h,n)=>{for(let i=0;i<n;i++){if((h[i>>3]>>(7-(i&7)))&1)return false}return true};
  c.addEventListener('click',async(ev)=>{if(busy||!ev.isTrusted)return;busy=true;b.innerHTML='<span class="spin"></span>';
    const p=document.querySelector('[name=puzzle]').value,enc=new TextEncoder();
    for(let n=0;;n++){const h=new Uint8Array(await crypto.subtle.digest('SHA-256',enc.encode(p+':'+n)));
      if(zeros(h,<?= GATE_BITS ?>)){document.getElementById('answer').value=n;break}}
    document.getElementById('took').value=Math.round(performance.now()-start);
    c.setAttribute('aria-checked','true');b.innerHTML='✓';setTimeout(()=>document.getElementById('f').submit(),250);});})();
  </script>
<?php endif; ?>
<?php if ($problem !== ''): ?><p class="err"><?= $e($problem) ?></p><?php endif; ?>
  <p class="small">No account and no tracking: passing leaves one small cookie in this browser so you aren't asked again.</p>
</form></body></html><?php
}

/** Only addresses on this site, never somewhere else. */
function gate_safe_back(string $back): string {
    return preg_match('#^/(?!/)[^\s\\\\]*$#', $back) ? $back : '/';
}

function gate_verify(): void {
    $back = gate_safe_back((string)($_POST['back'] ?? '/'));
    $config = gate_config();
    $secret = (string)($config['turnstile_secret'] ?? '');
    $ok = false;
    if ($secret !== '') {
        $token = (string)($_POST['cf-turnstile-response'] ?? '');
        $ctx = stream_context_create(['http' => [
            'method' => 'POST',
            'header' => "Content-Type: application/x-www-form-urlencoded\r\n",
            'content' => http_build_query(['secret' => $secret, 'response' => $token, 'remoteip' => $_SERVER['REMOTE_ADDR'] ?? '']),
            'timeout' => 6,
        ]]);
        $res = json_decode((string)@file_get_contents('https://challenges.cloudflare.com/turnstile/v0/siteverify', false, $ctx), true);
        $ok = is_array($res) && !empty($res['success']);
    } else {
        $puzzle = (string)($_POST['puzzle'] ?? '');
        $answer = (string)($_POST['answer'] ?? '');
        $parts = explode('.', $puzzle);
        if (count($parts) === 3 && ctype_digit($answer) && ctype_digit($parts[1])
            && hash_equals(substr(gate_sign('puzzle|' . $parts[0] . '.' . $parts[1]), 0, 32), $parts[2])) {
            $age = time() - (int)$parts[1];
            $hash = hash('sha256', $puzzle . ':' . $answer, true);
            $bits = 0;
            foreach (str_split($hash) as $byte) {
                $o = ord($byte);
                if ($o === 0) { $bits += 8; continue; }
                $bits += 7 - (int)floor(log($o, 2));
                break;
            }
            // Solved, not too old, and not instant (a person took a moment).
            $ok = $bits >= GATE_BITS && $age >= 1 && $age <= 600 && (int)($_POST['took'] ?? 0) >= 300;
        }
    }
    if (!$ok) {
        gate_count('failed');
        gate_page($back, "That didn't work. Please try once more.");
        exit;
    }
    gate_count('passed');
    gate_give_cookie();
    header('Location: ' . $back, true, 303);
    exit;
}

// Requests to gate.php itself: the tick, or /preview and /privacy.
if (realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    if (isset($_GET['verify']) && ($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
        gate_verify();
    }
    $page = (string)($_GET['page'] ?? '');
    $files = ['preview' => 'preview.html', 'privacy' => 'privacy.html'];
    if (!isset($files[$page])) {
        http_response_code(404);
        readfile(__DIR__ . '/404.html');
        exit;
    }
    human_gate('/' . $page);
    header('Content-Type: text/html; charset=utf-8');
    readfile(__DIR__ . '/' . $files[$page]);
}
