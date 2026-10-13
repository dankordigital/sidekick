<?php
// Sidekick's wishlist admin panel: email everyone on the list.
//
// Upload next to wishlist.php (in www). It uses wishlist.php's list and its
// mail settings, and asks for the password in wishlist-config.php
// ('admin_password', or the mailbox password if that isn't set): the
// password itself is never in this file or in git.
//
// Emails go out in small batches (the page sends the next one when the last
// is done), so the hosting's time limit is never hit. Each one carries the
// person's own "Remove me" link. A send that stopped half-way can be
// started again: nobody gets it twice.

declare(strict_types=1);

define('WISHLIST_LIB', true);
require __DIR__ . '/wishlist.php';

const BATCH = 8;                 // emails per request
const MAX_LOGIN_TRIES = 5;       // per visitor per 15 minutes

header('X-Robots-Tag: noindex, nofollow');
header('Cache-Control: no-store');
header('X-Frame-Options: DENY');
header('Referrer-Policy: no-referrer');

session_set_cookie_params([
    'lifetime' => 0,
    'path' => '/',
    'secure' => !$local,
    'httponly' => true,
    'samesite' => 'Strict',
]);
session_name('sk_admin');
session_start();

/** The panel's password, from wishlist-config.php (never in git). */
function admin_password(): ?string {
    $file = __DIR__ . '/wishlist-config.php';
    if (!is_readable($file)) return null;
    $config = include $file;
    if (!is_array($config)) return null;
    $p = $config['admin_password'] ?? $config['smtp_password'] ?? '';
    return $p !== '' ? $p : null;
}

/** At most MAX_LOGIN_TRIES wrong passwords per visitor per 15 minutes. */
function login_allowed(bool $failed = false): bool {
    $dir = data_dir();
    $key = hash('sha256', (string)@file_get_contents("$dir/.salt") . ($_SERVER['REMOTE_ADDR'] ?? ''));
    $file = "$dir/admin-limits.json";
    $h = fopen($file, 'c+');
    flock($h, LOCK_EX);
    $limits = json_decode(stream_get_contents($h) ?: '{}', true) ?: [];
    $now = time();
    foreach ($limits as $k => $times) {
        $limits[$k] = array_values(array_filter($times, fn($t) => $now - $t < 900));
        if (!$limits[$k]) unset($limits[$k]);
    }
    if ($failed) $limits[$key][] = $now;
    $ok = count($limits[$key] ?? []) < MAX_LOGIN_TRIES;
    ftruncate($h, 0);
    rewind($h);
    fwrite($h, json_encode($limits));
    flock($h, LOCK_UN);
    fclose($h);
    return $ok;
}

function csrf(): string {
    if (empty($_SESSION['csrf'])) $_SESSION['csrf'] = bin2hex(random_bytes(16));
    return $_SESSION['csrf'];
}

function check_csrf(): void {
    if (!hash_equals(csrf(), (string)($_POST['csrf'] ?? ''))) reply(403, ['error' => 'Session expired. Reload the page.']);
}

function signed_in(): bool {
    return ($_SESSION['admin'] ?? false) === true;
}

/** Everyone on the list, in a stable order. */
function list_rows(): array {
    return array_values(with_list(fn(array &$rows) => $rows));
}

/** The announcement, designed like the welcome email: the header image,
 *  a heading, the message and a "Remove me" link. */
function announce_html(string $heading, string $message, string $remove): string {
    $site = htmlspecialchars(SITE);
    $remove = htmlspecialchars($remove);
    $font = "font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif";
    $title = htmlspecialchars($heading);
    $paragraphs = '';
    foreach (preg_split('/\R{2,}/', trim($message)) as $p) {
        $p = nl2br(htmlspecialchars(trim($p)));
        // Links in the message become real links.
        $p = preg_replace('~(https?://[^\s<]+)~', '<a href="$1" style="color:#6a4cff">$1</a>', $p);
        $paragraphs .= "<p style=\"margin:0 0 16px;font-size:16px;line-height:1.55;color:#3d3550\">$p</p>\n";
    }
    return <<<HTML
<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light only"><title>$title</title></head>
<body style="margin:0;padding:0;background:#f1edf8">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f1edf8"><tr><td align="center" style="padding:24px 12px">
<table role="presentation" width="600" cellpadding="0" cellspacing="0" style="width:100%;max-width:600px;background:#ffffff;border-radius:24px;overflow:hidden">
<tr><td bgcolor="#2a1257" align="center" style="background:#2a1257"><a href="$site" style="color:#ffffff;text-decoration:none"><img src="cid:header" width="600" alt="Sidekick" style="display:block;width:100%;height:auto;border:0;background:#2a1257;color:#ffffff;$font;font-size:28px;font-weight:800;line-height:80px;text-align:center;text-decoration:none"></a></td></tr>
<tr><td style="padding:36px 40px 16px;$font;color:#1d1530">
<h1 style="margin:0 0 16px;font-size:28px;line-height:1.2;font-weight:800">$title</h1>
$paragraphs
</td></tr>
<tr><td style="padding:0 40px 32px;$font;font-size:13px;line-height:1.5;color:#8a8399;border-top:1px solid #eee8f6">
<p style="margin:22px 0 0">You're getting this because you joined the Sidekick wishlist. <a href="$remove" style="color:#8a8399">Remove me from the list</a>.</p>
</td></tr>
</table>
<p style="margin:18px 0 0;$font;font-size:13px;color:#a39cb3">Sidekick · <a href="$site" style="color:#a39cb3">getsidekick.app</a></p>
</td></tr></table>
</body></html>
HTML;
}

function send_announcement(string $to, string $token, string $subject, string $heading, string $message): bool {
    global $site;
    $remove = "$site/wishlist.php?remove=$token";
    $text = ($heading !== '' ? "$heading\r\n\r\n" : '')
        . str_replace(["\r\n", "\n"], "\r\n", trim($message)) . "\r\n\r\n"
        . "You're getting this because you joined the Sidekick wishlist.\r\n"
        . "Remove me from the list: $remove\r\n\r\nSidekick\r\ngetsidekick.app\r\n";
    return send_mail($to, $subject, $text, FROM_NAME, FROM, ['List-Unsubscribe: <' . $remove . '>'],
        announce_html($heading !== '' ? $heading : $subject, $message, $remove));
}

/** Who a send already reached, so starting it again skips them. */
function sent_file(string $id): string {
    $dir = data_dir() . '/sends';
    if (!is_dir($dir)) @mkdir($dir, 0700);
    return "$dir/" . preg_replace('/[^a-f0-9]/', '', $id) . '.txt';
}

// ------------------------------------------------------------------ actions

$action = $_POST['action'] ?? '';

if ($action === 'login') {
    $password = admin_password();
    if ($password === null) {
        $error = 'No password set: put wishlist-config.php next to this page.';
    } elseif (!login_allowed()) {
        $error = 'Too many tries. Wait 15 minutes.';
    } elseif (hash_equals($password, (string)($_POST['password'] ?? ''))) {
        session_regenerate_id(true);
        $_SESSION['admin'] = true;
        header('Location: ' . strtok($_SERVER['REQUEST_URI'] ?? 'np7dpanel.php', '?'), true, 303);
        exit;
    } else {
        login_allowed(true);
        $error = 'Wrong password.';
    }
}

if ($action === 'logout') {
    $_SESSION = [];
    session_destroy();
    header('Location: ' . strtok($_SERVER['REQUEST_URI'] ?? 'np7dpanel.php', '?'), true, 303);
    exit;
}

if (in_array($action, ['test', 'batch'], true)) {
    if (!signed_in()) reply(401, ['error' => 'Signed out. Reload the page.']);
    check_csrf();
    $subject = trim((string)($_POST['subject'] ?? ''));
    $heading = trim((string)($_POST['heading'] ?? ''));
    $message = trim((string)($_POST['message'] ?? ''));
    if ($subject === '' || $message === '') reply(400, ['error' => 'Write a subject and a message first.']);
    @set_time_limit(120);

    if ($action === 'test') {
        $ok = send_announcement(FROM, 'test', $subject, $heading, $message);
        reply($ok ? 200 : 500, $ok ? ['ok' => true] : ['error' => 'The test email failed. See sidekick-wishlist/mail.log.']);
    }

    // One batch of the real send.
    $id = (string)($_POST['id'] ?? '');
    if (!preg_match('/^[a-f0-9]{16,64}$/', $id)) reply(400, ['error' => 'Bad send id.']);
    $file = sent_file($id);
    $done = is_readable($file) ? array_flip(file($file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES)) : [];
    $rows = list_rows();
    $todo = array_values(array_filter($rows, fn($r) => !isset($done[$r['email']])));
    $failed = [];
    foreach (array_slice($todo, 0, BATCH) as $row) {
        if (send_announcement($row['email'], $row['token'], $subject, $heading, $message)) {
            file_put_contents($file, $row['email'] . "\n", FILE_APPEND | LOCK_EX);
        } else {
            $failed[] = $row['email'];
            // Counted as done for this send, so one bad address can't stall it.
            file_put_contents($file, $row['email'] . "\n", FILE_APPEND | LOCK_EX);
        }
    }
    $remaining = max(0, count($todo) - BATCH);
    reply(200, ['total' => count($rows), 'remaining' => $remaining, 'failed' => $failed]);
}

$count = signed_in() ? count(list_rows()) : 0;
$token = csrf();
?><!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>Sidekick admin</title>
<style>
  :root { color-scheme: light dark; --bg:#f5f3fa; --card:#fff; --ink:#1d1530; --muted:#6b6480; --line:#e6e1f0; --accent:#6a4cff; --bad:#c62828; --good:#2e7d32; }
  @media (prefers-color-scheme: dark) { :root { --bg:#131118; --card:#1d1a24; --ink:#eeeaf6; --muted:#a39db3; --line:#2e2a38; --accent:#a48dff; } }
  * { box-sizing: border-box; }
  body { margin:0; background:var(--bg); color:var(--ink); font:16px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; }
  main { max-width:640px; margin:0 auto; padding:40px 16px; }
  h1 { font-size:24px; margin:0 0 4px; }
  .muted { color:var(--muted); margin:0 0 24px; }
  .card { background:var(--card); border:1px solid var(--line); border-radius:16px; padding:20px; }
  label { display:block; font-weight:600; font-size:14px; margin:16px 0 6px; }
  label:first-child { margin-top:0; }
  input, textarea { width:100%; padding:12px 14px; border:1px solid var(--line); border-radius:10px; background:transparent; color:inherit; font:inherit; }
  textarea { min-height:200px; resize:vertical; }
  .row { display:flex; gap:10px; flex-wrap:wrap; margin-top:20px; }
  button { padding:12px 20px; border:0; border-radius:10px; font:inherit; font-weight:600; cursor:pointer; background:var(--line); color:var(--ink); }
  button.primary { background:var(--accent); color:#fff; }
  button:disabled { opacity:.5; cursor:default; }
  .bar { height:8px; background:var(--line); border-radius:4px; overflow:hidden; margin-top:16px; display:none; }
  .bar i { display:block; height:100%; width:0; background:var(--accent); transition:width .3s; }
  #status { margin-top:12px; font-size:14px; }
  .bad { color:var(--bad); } .good { color:var(--good); }
  form.out { margin-top:32px; text-align:right; }
  form.out button { background:none; color:var(--muted); padding:0; }
</style>
</head>
<body>
<main>
<?php if (!signed_in()): ?>
  <h1>Sidekick admin</h1>
  <p class="muted">Sign in to email the wishlist.</p>
  <form class="card" method="post" autocomplete="off">
    <input type="hidden" name="action" value="login">
    <label for="password">Password</label>
    <input id="password" name="password" type="password" required autofocus>
    <?php if (!empty($error)): ?><p class="bad"><?= htmlspecialchars($error) ?></p><?php endif; ?>
    <div class="row"><button class="primary" type="submit">Sign in</button></div>
  </form>
<?php else: ?>
  <h1>Email the wishlist</h1>
  <p class="muted"><?= $count ?> <?= $count === 1 ? 'person is' : 'people are' ?> on the list. Each email has their own "Remove me" link.</p>
  <div class="card">
    <label for="subject">Subject</label>
    <input id="subject" maxlength="150" placeholder="Sidekick is out!">
    <label for="heading">Heading in the email (optional)</label>
    <input id="heading" maxlength="150" placeholder="Sidekick is here">
    <label for="message">Message</label>
    <textarea id="message" placeholder="Write your message. Leave an empty line between paragraphs. Links become clickable."></textarea>
    <div class="row">
      <button id="test" type="button">Send a test to <?= htmlspecialchars(FROM) ?></button>
      <button id="send" class="primary" type="button">Send to all <?= $count ?></button>
    </div>
    <div class="bar" id="bar"><i></i></div>
    <p id="status"></p>
  </div>
  <form class="out" method="post"><input type="hidden" name="action" value="logout"><button>Sign out</button></form>
<script>
const csrf = <?= json_encode($token) ?>;
const $ = (id) => document.getElementById(id);
const status = (text, kind) => { $('status').textContent = text; $('status').className = kind || ''; };
const fields = () => ({ subject: $('subject').value.trim(), heading: $('heading').value.trim(), message: $('message').value.trim() });

async function post(data) {
  const body = new URLSearchParams({ csrf, ...data });
  const res = await fetch(location.pathname, { method: 'POST', body });
  const json = await res.json().catch(() => ({ error: 'The server sent something unexpected.' }));
  if (!res.ok) throw new Error(json.error || 'Failed');
  return json;
}

$('test').onclick = async () => {
  const f = fields();
  if (!f.subject || !f.message) return status('Write a subject and a message first.', 'bad');
  $('test').disabled = true;
  status('Sending a test…');
  try { await post({ action: 'test', ...f }); status('Test sent. Check the inbox of <?= htmlspecialchars(FROM) ?>.', 'good'); }
  catch (e) { status(e.message, 'bad'); }
  $('test').disabled = false;
};

$('send').onclick = async () => {
  const f = fields();
  if (!f.subject || !f.message) return status('Write a subject and a message first.', 'bad');
  if (!confirm('Send "' + f.subject + '" to everyone on the list? This can\'t be undone.')) return;
  // The same id for this text: sending again later skips whoever got it.
  const id = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(f.subject + '\n' + f.heading + '\n' + f.message))))
    .slice(0, 16).map((b) => b.toString(16).padStart(2, '0')).join('');
  $('send').disabled = $('test').disabled = true;
  $('bar').style.display = 'block';
  const failed = [];
  try {
    for (;;) {
      const r = await post({ action: 'batch', id, ...f });
      failed.push(...r.failed);
      const done = r.total - r.remaining;
      $('bar').firstElementChild.style.width = (r.total ? 100 * done / r.total : 100) + '%';
      status('Sent ' + done + ' of ' + r.total + '…');
      if (r.remaining === 0) break;
    }
    status(failed.length ? 'Done. Couldn\'t send to: ' + failed.join(', ') : 'Done: everyone on the list has it.', failed.length ? 'bad' : 'good');
  } catch (e) {
    status(e.message + ' Click Send again to carry on where it stopped.', 'bad');
  }
  $('send').disabled = $('test').disabled = false;
};
</script>
<?php endif; ?>
</main>
</body>
</html>
