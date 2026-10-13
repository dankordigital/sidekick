<?php
// Sidekick's admin panel: the wishlist at a glance, everyone on it, emailing
// them all, past sends, the mail log and a health check.
//
// Upload next to wishlist.php (in www). It uses wishlist.php's list and mail
// settings, and asks for the password in wishlist-config.php
// ('admin_password', or the mailbox password if that isn't set): the
// password itself is never in this file or in git.
//
// Emails to everyone go out in small batches (the page asks for the next one
// when the last is done), so the hosting's time limit is never hit. Each
// carries the person's own "Remove me" link. A send that stopped half-way
// can be started again: nobody gets it twice.

declare(strict_types=1);

define('WISHLIST_LIB', true);
require __DIR__ . '/wishlist.php';

const BATCH = 8;                 // emails per request
const MAX_LOGIN_TRIES = 5;       // per visitor per 15 minutes
const DEVICES = ['Windows', 'Mac', 'Android', 'iPhone'];

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

$self = strtok($_SERVER['REQUEST_URI'] ?? 'np7dpanel.php', '?');

// ------------------------------------------------------------------ helpers

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
    $h = fopen("$dir/admin-limits.json", 'c+');
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

function csrf_ok(): bool {
    return hash_equals(csrf(), (string)($_POST['csrf'] ?? ''));
}

function signed_in(): bool {
    return ($_SESSION['admin'] ?? false) === true;
}

function e(?string $s): string {
    return htmlspecialchars((string)$s, ENT_QUOTES);
}

/** A message shown once after the next page load. */
function flash(string $text, bool $bad = false): void {
    $_SESSION['flash'] = [$text, $bad];
}

function go(string $tab, array $query = []): void {
    global $self;
    $query = ['tab' => $tab] + $query;
    header('Location: ' . $self . '?' . http_build_query($query), true, 303);
    exit;
}

/** Everyone on the list, newest first. */
function people(): array {
    $rows = array_values(with_list(fn(array &$rows) => $rows));
    usort($rows, fn($a, $b) => strcmp($b['joined'], $a['joined']));
    return $rows;
}

function welcome_to(string $email): bool {
    $token = with_list(fn(array &$rows) => $rows[$email]['token'] ?? null);
    if ($token === null) return false;
    $sent = send_welcome($email, $token);
    if ($sent) {
        with_list(function (array &$rows) use ($email) {
            if (isset($rows[$email])) $rows[$email]['emailed'] = gmdate('Y-m-d H:i:s');
        });
    }
    return $sent;
}

/** The announcement, designed like the welcome email: the header image,
 *  a heading, the message and a "Remove me" link. */
function announce_html(string $heading, string $message, string $remove): string {
    $site = e(SITE);
    $remove = e($remove);
    $font = "font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif";
    $title = e($heading);
    $paragraphs = '';
    foreach (preg_split('/\R{2,}/', trim($message)) as $p) {
        $p = nl2br(e(trim($p)));
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

/** Past sends: sends/<id>.json (what and when) and <id>.txt (who got it). */
function sends_dir(): string {
    $dir = data_dir() . '/sends';
    if (!is_dir($dir)) @mkdir($dir, 0700);
    return $dir;
}

function sends(): array {
    $out = [];
    foreach (glob(sends_dir() . '/*.json') ?: [] as $file) {
        $meta = json_decode((string)file_get_contents($file), true) ?: [];
        $txt = substr($file, 0, -5) . '.txt';
        $meta['reached'] = is_readable($txt) ? count(file($txt, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES)) : 0;
        $out[] = $meta;
    }
    usort($out, fn($a, $b) => strcmp($b['started'] ?? '', $a['started'] ?? ''));
    return $out;
}

function mail_lines(int $max): array {
    $file = data_dir() . '/mail.log';
    if (!is_readable($file)) return [];
    $lines = file($file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [];
    return array_reverse(array_slice($lines, -$max));
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
        go('overview');
    } else {
        login_allowed(true);
        $error = 'Wrong password.';
    }
}

if ($action !== '' && $action !== 'login') {
    $json = in_array($action, ['test', 'batch'], true);
    if (!signed_in()) {
        if ($json) reply(401, ['error' => 'Signed out. Reload the page.']);
        go('overview');
    }
    if (!csrf_ok()) {
        if ($json) reply(403, ['error' => 'Session expired. Reload the page.']);
        flash('That form was too old. Try again.', true);
        go($_POST['tab'] ?? 'overview');
    }
    @set_time_limit(120);
    $email = strtolower(trim((string)($_POST['email'] ?? '')));

    switch ($action) {
        case 'logout':
            $_SESSION = [];
            session_destroy();
            go('overview');

        case 'add':
            if (strlen($email) > 254 || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
                flash('That isn\'t an email address.', true);
                go('people');
            }
            $devices = array_values(array_intersect((array)($_POST['devices'] ?? []), DEVICES));
            $added = with_list(function (array &$rows) use ($email, $devices) {
                if (isset($rows[$email])) return false;
                $rows[$email] = ['email' => $email, 'devices' => implode(' ', $devices), 'joined' => gmdate('Y-m-d H:i:s'),
                                 'token' => bin2hex(random_bytes(16)), 'emailed' => ''];
                return true;
            });
            if (!$added) {
                flash("$email is already on the list.", true);
            } elseif (!empty($_POST['welcome'])) {
                $sent = welcome_to($email);
                flash($sent ? "Added $email and sent the welcome email." : "Added $email, but the welcome email failed (see Mail log).", !$sent);
            } else {
                flash("Added $email.");
            }
            go('people');

        case 'remove':
            $gone = with_list(function (array &$rows) use ($email) {
                if (!isset($rows[$email])) return false;
                unset($rows[$email]);
                return true;
            });
            flash($gone ? "Removed $email." : "$email wasn't on the list.", !$gone);
            go('people', ['q' => $_POST['q'] ?? '']);

        case 'welcome':
            $sent = welcome_to($email);
            flash($sent ? "Welcome email sent to $email." : "Couldn't send to $email (see Mail log).", !$sent);
            go('people', ['q' => $_POST['q'] ?? '']);

        case 'welcome_missing':
            $missing = array_column(array_filter(people(), fn($r) => $r['emailed'] === ''), 'email');
            $sent = 0;
            foreach (array_slice($missing, 0, 20) as $m) {
                if (welcome_to($m)) $sent++;
            }
            $left = max(0, count($missing) - 20);
            flash("Sent $sent welcome email" . ($sent === 1 ? '' : 's') . ($left ? ". $left still to go: press it again." : '.'), $sent < min(20, count($missing)));
            go('people');

        case 'clear_log':
            @file_put_contents(data_dir() . '/mail.log', '');
            flash('Mail log cleared.');
            go('log');

        case 'test':
        case 'batch':
            $subject = trim((string)($_POST['subject'] ?? ''));
            $heading = trim((string)($_POST['heading'] ?? ''));
            $message = trim((string)($_POST['message'] ?? ''));
            if ($subject === '' || $message === '') reply(400, ['error' => 'Write a subject and a message first.']);
            if ($action === 'test') {
                $ok = send_announcement(FROM, 'test', $subject, $heading, $message);
                reply($ok ? 200 : 500, $ok ? ['ok' => true] : ['error' => 'The test email failed. See the Mail log tab.']);
            }
            $id = (string)($_POST['id'] ?? '');
            if (!preg_match('/^[a-f0-9]{16,64}$/', $id)) reply(400, ['error' => 'Bad send id.']);
            $base = sends_dir() . "/$id";
            $rows = people();
            if (!is_file("$base.json")) {
                file_put_contents("$base.json", json_encode(['subject' => $subject, 'started' => gmdate('Y-m-d H:i:s'), 'total' => count($rows)]));
            }
            $done = is_readable("$base.txt") ? array_flip(file("$base.txt", FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES)) : [];
            $todo = array_values(array_filter($rows, fn($r) => !isset($done[$r['email']])));
            $failed = [];
            foreach (array_slice($todo, 0, BATCH) as $row) {
                if (!send_announcement($row['email'], $row['token'], $subject, $heading, $message)) $failed[] = $row['email'];
                // Counted as done either way, so one bad address can't stall it.
                file_put_contents("$base.txt", $row['email'] . "\n", FILE_APPEND | LOCK_EX);
            }
            reply(200, ['total' => count($rows), 'remaining' => max(0, count($todo) - BATCH), 'failed' => $failed]);
    }
    go('overview');
}

// The list as a spreadsheet.
if (signed_in() && ($_GET['export'] ?? '') === 'csv') {
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="sidekick-wishlist-' . gmdate('Y-m-d') . '.csv"');
    $out = fopen('php://output', 'w');
    fputcsv($out, ['email', 'devices', 'joined (UTC)', 'welcome email sent (UTC)'], ',', '"', '');
    foreach (people() as $r) fputcsv($out, [$r['email'], $r['devices'], $r['joined'], $r['emailed']], ',', '"', '');
    exit;
}

// ------------------------------------------------------------------ page

$tabs = ['overview' => 'Overview', 'people' => 'People', 'email' => 'Email everyone', 'sends' => 'Past sends', 'log' => 'Mail log', 'health' => 'Health'];
$tab = array_key_exists($_GET['tab'] ?? '', $tabs) ? $_GET['tab'] : 'overview';
$flash = $_SESSION['flash'] ?? null;
unset($_SESSION['flash']);
$token = csrf();
$rows = signed_in() ? people() : [];
$count = count($rows);

function form_start(string $action, string $tab, array $hidden = []): string {
    $h = '<form method="post" class="inline"><input type="hidden" name="action" value="' . e($action) . '">'
        . '<input type="hidden" name="csrf" value="' . e(csrf()) . '"><input type="hidden" name="tab" value="' . e($tab) . '">';
    foreach ($hidden as $k => $v) $h .= '<input type="hidden" name="' . e($k) . '" value="' . e((string)$v) . '">';
    return $h;
}
?><!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>Sidekick admin</title>
<style>
  :root { color-scheme: light dark; --bg:#f5f3fa; --card:#fff; --ink:#1d1530; --muted:#6b6480; --line:#e6e1f0; --soft:#efebf7; --accent:#6a4cff; --bad:#c62828; --good:#2e7d32; }
  @media (prefers-color-scheme: dark) { :root { --bg:#131118; --card:#1d1a24; --ink:#eeeaf6; --muted:#a39db3; --line:#2e2a38; --soft:#26222f; --accent:#a48dff; --bad:#ef7070; --good:#6fcf7a; } }
  * { box-sizing: border-box; }
  body { margin:0; background:var(--bg); color:var(--ink); font:15px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; }
  main { max-width:960px; margin:0 auto; padding:32px 16px 64px; }
  header { display:flex; align-items:center; justify-content:space-between; gap:12px; margin-bottom:16px; }
  h1 { font-size:22px; margin:0; }
  h2 { font-size:17px; margin:0 0 12px; }
  nav { display:flex; gap:4px; flex-wrap:wrap; border-bottom:1px solid var(--line); margin-bottom:24px; }
  nav a { padding:10px 14px; color:var(--muted); text-decoration:none; border-bottom:2px solid transparent; margin-bottom:-1px; font-weight:500; }
  nav a.on { color:var(--ink); border-color:var(--accent); }
  .muted { color:var(--muted); }
  .card { background:var(--card); border:1px solid var(--line); border-radius:14px; padding:20px; margin-bottom:16px; }
  .stats { display:grid; grid-template-columns:repeat(auto-fit,minmax(170px,1fr)); gap:12px; margin-bottom:16px; }
  .stat { background:var(--card); border:1px solid var(--line); border-radius:14px; padding:16px 18px; }
  .stat b { display:block; font-size:28px; line-height:1.2; }
  .stat span { color:var(--muted); font-size:13px; }
  .grid2 { display:grid; grid-template-columns:repeat(auto-fit,minmax(300px,1fr)); gap:16px; }
  .bars { display:flex; align-items:flex-end; gap:3px; height:120px; }
  .bars div { flex:1; background:var(--accent); border-radius:3px 3px 0 0; min-height:2px; opacity:.85; }
  .axis { display:flex; justify-content:space-between; font-size:12px; color:var(--muted); margin-top:6px; }
  .hbar { display:grid; grid-template-columns:80px 1fr 40px; align-items:center; gap:10px; margin:8px 0; font-size:14px; }
  .hbar i { display:block; height:10px; border-radius:5px; background:var(--accent); }
  .hbar .track { background:var(--soft); border-radius:5px; }
  table { width:100%; border-collapse:collapse; font-size:14px; }
  th, td { text-align:left; padding:10px 8px; border-bottom:1px solid var(--line); vertical-align:middle; }
  th { color:var(--muted); font-weight:500; font-size:13px; }
  td.actions { text-align:right; white-space:nowrap; }
  .tablewrap { overflow-x:auto; }
  label { display:block; font-weight:600; font-size:14px; margin:14px 0 6px; }
  input[type=text], input[type=email], input[type=password], input[type=search], textarea { width:100%; padding:11px 13px; border:1px solid var(--line); border-radius:10px; background:transparent; color:inherit; font:inherit; }
  textarea { min-height:200px; resize:vertical; }
  .checks { display:flex; gap:14px; flex-wrap:wrap; font-weight:400; }
  .checks label { display:flex; gap:6px; align-items:center; margin:0; font-weight:400; }
  .row { display:flex; gap:10px; flex-wrap:wrap; align-items:center; margin-top:16px; }
  button, .btn { display:inline-block; padding:10px 18px; border:0; border-radius:10px; font:inherit; font-weight:600; cursor:pointer; background:var(--soft); color:var(--ink); text-decoration:none; }
  button.primary, .btn.primary { background:var(--accent); color:#fff; }
  button.small { padding:6px 12px; font-size:13px; }
  button.danger { color:var(--bad); }
  button:disabled { opacity:.5; cursor:default; }
  form.inline { display:inline; }
  .notice { padding:12px 16px; border-radius:10px; margin-bottom:16px; background:var(--soft); }
  .notice.bad { color:var(--bad); }
  .bar { height:8px; background:var(--soft); border-radius:4px; overflow:hidden; margin-top:16px; display:none; }
  .bar i { display:block; height:100%; width:0; background:var(--accent); transition:width .3s; }
  .bad { color:var(--bad); } .good { color:var(--good); }
  .pill { font-size:12px; padding:2px 8px; border-radius:999px; background:var(--soft); color:var(--muted); }
  pre.log { margin:0; white-space:pre-wrap; word-break:break-word; font:13px/1.6 ui-monospace,Menlo,Consolas,monospace; }
  .checklist div { padding:8px 0; border-bottom:1px solid var(--line); }
  .checklist div:last-child { border:0; }
  .login { max-width:400px; margin:10vh auto 0; }
</style>
</head>
<body>
<main>
<?php if (!signed_in()): ?>
  <div class="login">
    <h1>Sidekick admin</h1>
    <p class="muted">Sign in to manage the wishlist.</p>
    <form class="card" method="post" autocomplete="off">
      <input type="hidden" name="action" value="login">
      <label for="password" style="margin-top:0">Password</label>
      <input id="password" name="password" type="password" required autofocus>
      <?php if (!empty($error)): ?><p class="bad"><?= e($error) ?></p><?php endif; ?>
      <div class="row"><button class="primary" type="submit">Sign in</button></div>
    </form>
  </div>
<?php else: ?>
  <header>
    <h1>Sidekick admin</h1>
    <?= form_start('logout', $tab) ?><button class="small">Sign out</button></form>
  </header>
  <nav>
    <?php foreach ($tabs as $k => $label): ?>
      <a href="?tab=<?= $k ?>" class="<?= $k === $tab ? 'on' : '' ?>"><?= e($label) ?></a>
    <?php endforeach; ?>
  </nav>
  <?php if ($flash): ?><div class="notice <?= $flash[1] ? 'bad' : '' ?>"><?= e($flash[0]) ?></div><?php endif; ?>

<?php if ($tab === 'overview'):
    $now = time();
    $since = fn(int $days) => count(array_filter($rows, fn($r) => $now - strtotime($r['joined'] . ' UTC') < $days * 86400));
    $noWelcome = count(array_filter($rows, fn($r) => $r['emailed'] === ''));
    // Sign-ups per day, the last 30 days.
    $days = [];
    for ($i = 29; $i >= 0; $i--) $days[gmdate('Y-m-d', $now - $i * 86400)] = 0;
    foreach ($rows as $r) {
        $d = substr($r['joined'], 0, 10);
        if (isset($days[$d])) $days[$d]++;
    }
    $peak = max(1, max($days));
    $byDevice = array_fill_keys(DEVICES, 0);
    $none = 0;
    foreach ($rows as $r) {
        $ds = array_filter(explode(' ', $r['devices']));
        if (!$ds) $none++;
        foreach ($ds as $d) if (isset($byDevice[$d])) $byDevice[$d]++;
    }
    $devPeak = max(1, max($byDevice), $none);
?>
  <div class="stats">
    <div class="stat"><b><?= $count ?></b><span>on the wishlist</span></div>
    <div class="stat"><b><?= $since(1) ?></b><span>joined today (24 h)</span></div>
    <div class="stat"><b><?= $since(7) ?></b><span>joined this week</span></div>
    <div class="stat"><b><?= $since(30) ?></b><span>joined in 30 days</span></div>
    <div class="stat"><b class="<?= $noWelcome ? 'bad' : '' ?>"><?= $noWelcome ?></b><span>never got the welcome email</span></div>
  </div>
  <div class="grid2">
    <div class="card">
      <h2>Sign-ups, last 30 days</h2>
      <div class="bars">
        <?php foreach ($days as $d => $n): ?><div style="height:<?= round(100 * $n / $peak) ?>%" title="<?= e($d) ?>: <?= $n ?>"></div><?php endforeach; ?>
      </div>
      <div class="axis"><span><?= e(gmdate('j M', $now - 29 * 86400)) ?></span><span>today</span></div>
    </div>
    <div class="card">
      <h2>What they use</h2>
      <?php foreach ($byDevice + ['Not said' => $none] as $d => $n): ?>
        <div class="hbar"><span><?= e($d) ?></span><div class="track"><i style="width:<?= round(100 * $n / $devPeak) ?>%"></i></div><span><?= $n ?></span></div>
      <?php endforeach; ?>
    </div>
  </div>
  <div class="card">
    <h2>Newest</h2>
    <?php if (!$rows): ?><p class="muted">Nobody yet.</p><?php else: ?>
    <div class="tablewrap"><table>
      <tr><th>Email</th><th>Uses</th><th>Joined (UTC)</th></tr>
      <?php foreach (array_slice($rows, 0, 8) as $r): ?>
        <tr><td><?= e($r['email']) ?></td><td><?= e($r['devices'] ?: '–') ?></td><td><?= e($r['joined']) ?></td></tr>
      <?php endforeach; ?>
    </table></div>
    <p><a href="?tab=people">Everyone →</a></p>
    <?php endif; ?>
  </div>

<?php elseif ($tab === 'people'):
    $q = strtolower(trim((string)($_GET['q'] ?? '')));
    $shown = $q === '' ? $rows : array_values(array_filter($rows, fn($r) => str_contains($r['email'], $q) || str_contains(strtolower($r['devices']), $q)));
    $missing = count(array_filter($rows, fn($r) => $r['emailed'] === ''));
?>
  <div class="card">
    <form method="get" class="row" style="margin:0">
      <input type="hidden" name="tab" value="people">
      <input type="search" name="q" value="<?= e($q) ?>" placeholder="Search email or device" style="flex:1;min-width:200px">
      <button>Search</button>
      <a class="btn" href="?export=csv">Download as spreadsheet (.csv)</a>
    </form>
    <?php if ($missing): ?>
      <div class="row">
        <span class="muted"><?= $missing ?> <?= $missing === 1 ? 'person never got' : 'people never got' ?> the welcome email.</span>
        <?= form_start('welcome_missing', 'people') ?><button class="small">Send it to them</button></form>
      </div>
    <?php endif; ?>
  </div>
  <div class="card">
    <h2><?= $q === '' ? "Everyone ($count)" : count($shown) . " found" ?></h2>
    <?php if (!$shown): ?><p class="muted">Nobody here.</p><?php else: ?>
    <div class="tablewrap"><table>
      <tr><th>Email</th><th>Uses</th><th>Joined (UTC)</th><th>Welcome email</th><th></th></tr>
      <?php foreach ($shown as $r): ?>
        <tr>
          <td><?= e($r['email']) ?></td>
          <td><?= e($r['devices'] ?: '–') ?></td>
          <td><?= e($r['joined']) ?></td>
          <td><?= $r['emailed'] !== '' ? '<span class="pill">sent</span>' : '<span class="bad">not sent</span>' ?></td>
          <td class="actions">
            <?= form_start('welcome', 'people', ['email' => $r['email'], 'q' => $q]) ?><button class="small">Send welcome</button></form>
            <?= form_start('remove', 'people', ['email' => $r['email'], 'q' => $q]) ?><button class="small danger" onclick="return confirm('Remove <?= e($r['email']) ?> from the list?')">Remove</button></form>
          </td>
        </tr>
      <?php endforeach; ?>
    </table></div>
    <?php endif; ?>
  </div>
  <div class="card">
    <h2>Add someone</h2>
    <?= form_start('add', 'people') ?>
      <label for="add-email" style="margin-top:0">Email</label>
      <input id="add-email" type="email" name="email" required>
      <label>Uses</label>
      <div class="checks">
        <?php foreach (DEVICES as $d): ?><label><input type="checkbox" name="devices[]" value="<?= $d ?>"> <?= $d ?></label><?php endforeach; ?>
      </div>
      <div class="checks" style="margin-top:12px"><label><input type="checkbox" name="welcome" value="1" checked> Send them the welcome email</label></div>
      <div class="row"><button class="primary">Add</button></div>
    </form>
  </div>

<?php elseif ($tab === 'email'): ?>
  <div class="card">
    <h2>Email everyone</h2>
    <p class="muted" style="margin-top:0"><?= $count ?> <?= $count === 1 ? 'person is' : 'people are' ?> on the list. Each email has their own "Remove me" link and the Sidekick header.</p>
    <label for="subject">Subject</label>
    <input type="text" id="subject" maxlength="150" placeholder="Sidekick is out!">
    <label for="heading">Heading in the email (optional)</label>
    <input type="text" id="heading" maxlength="150" placeholder="Sidekick is here">
    <label for="message">Message</label>
    <textarea id="message" placeholder="Leave an empty line between paragraphs. Links become clickable."></textarea>
    <div class="row">
      <button id="test" type="button">Send a test to <?= e(FROM) ?></button>
      <button id="send" class="primary" type="button">Send to all <?= $count ?></button>
    </div>
    <div class="bar" id="bar"><i></i></div>
    <p id="status"></p>
  </div>
<script>
const csrf = <?= json_encode($token) ?>;
const $ = (id) => document.getElementById(id);
const say = (text, kind) => { $('status').textContent = text; $('status').className = kind || ''; };
const fields = () => ({ subject: $('subject').value.trim(), heading: $('heading').value.trim(), message: $('message').value.trim() });
// Keep a half-written email if the page is closed.
for (const k of ['subject', 'heading', 'message']) {
  try { $(k).value = localStorage.getItem('sk-admin-' + k) || ''; } catch (_) {}
  $(k).addEventListener('input', () => { try { localStorage.setItem('sk-admin-' + k, $(k).value); } catch (_) {} });
}
async function post(data) {
  const res = await fetch(location.pathname, { method: 'POST', body: new URLSearchParams({ csrf, ...data }) });
  const json = await res.json().catch(() => ({ error: 'The server sent something unexpected.' }));
  if (!res.ok) throw new Error(json.error || 'Failed');
  return json;
}
$('test').onclick = async () => {
  const f = fields();
  if (!f.subject || !f.message) return say('Write a subject and a message first.', 'bad');
  $('test').disabled = true;
  say('Sending a test…');
  try { await post({ action: 'test', ...f }); say('Test sent. Check the inbox of <?= e(FROM) ?>.', 'good'); }
  catch (e) { say(e.message, 'bad'); }
  $('test').disabled = false;
};
$('send').onclick = async () => {
  const f = fields();
  if (!f.subject || !f.message) return say('Write a subject and a message first.', 'bad');
  if (!confirm('Send "' + f.subject + '" to everyone on the list? This can\'t be undone.')) return;
  // The same id for the same text: sending again later skips whoever got it.
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(f.subject + '\n' + f.heading + '\n' + f.message));
  const id = Array.from(new Uint8Array(digest)).slice(0, 16).map((b) => b.toString(16).padStart(2, '0')).join('');
  $('send').disabled = $('test').disabled = true;
  $('bar').style.display = 'block';
  const failed = [];
  try {
    for (;;) {
      const r = await post({ action: 'batch', id, ...f });
      failed.push(...r.failed);
      const done = r.total - r.remaining;
      $('bar').firstElementChild.style.width = (r.total ? 100 * done / r.total : 100) + '%';
      say('Sent ' + done + ' of ' + r.total + '…');
      if (r.remaining === 0) break;
    }
    say(failed.length ? 'Done. Couldn\'t send to: ' + failed.join(', ') : 'Done: everyone on the list has it.', failed.length ? 'bad' : 'good');
  } catch (e) {
    say(e.message + ' Press Send again to carry on where it stopped.', 'bad');
  }
  $('send').disabled = $('test').disabled = false;
};
</script>

<?php elseif ($tab === 'sends'): $all = sends(); ?>
  <div class="card">
    <h2>Past sends</h2>
    <?php if (!$all): ?><p class="muted">Nothing sent to everyone yet.</p><?php else: ?>
    <div class="tablewrap"><table>
      <tr><th>Subject</th><th>Started (UTC)</th><th>Reached</th></tr>
      <?php foreach ($all as $s): ?>
        <tr><td><?= e($s['subject'] ?? '?') ?></td><td><?= e($s['started'] ?? '') ?></td><td><?= (int)$s['reached'] ?> of <?= (int)($s['total'] ?? 0) ?></td></tr>
      <?php endforeach; ?>
    </table></div>
    <?php endif; ?>
  </div>

<?php elseif ($tab === 'log'): $lines = mail_lines(200); ?>
  <div class="card">
    <header style="margin-bottom:12px"><h2 style="margin:0">Mail log</h2>
      <?php if ($lines): ?><?= form_start('clear_log', 'log') ?><button class="small" onclick="return confirm('Clear the mail log?')">Clear</button></form><?php endif; ?>
    </header>
    <p class="muted" style="margin-top:0">Only failures are written here, newest first. It never contains the password.</p>
    <?php if (!$lines): ?><p class="good">Nothing has failed.</p><?php else: ?><pre class="log"><?= e(implode("\n", $lines)) ?></pre><?php endif; ?>
  </div>

<?php elseif ($tab === 'health'):
    $ok = fn(bool $b) => $b ? '<span class="good">✔</span>' : '<span class="bad">✘</span>';
    $dir = data_dir();
    $outside = !str_starts_with(realpath($dir) ?: $dir, realpath(__DIR__) ?: __DIR__);
    $reach = [];
    foreach (SMTP_PORTS as $port) {
        $s = @fsockopen(($port === 465 ? 'ssl://' : '') . SMTP_HOST, $port, $errno, $errstr, 5);
        $reach[$port] = (bool)$s;
        if ($s) fclose($s);
    }
?>
  <div class="card checklist">
    <h2>Health</h2>
    <div><?= $ok(PHP_VERSION_ID >= 80000) ?> PHP <?= e(PHP_VERSION) ?></div>
    <div><?= $ok(extension_loaded('openssl')) ?> Secure connections (openssl)</div>
    <div><?= $ok(is_writable($dir)) ?> The list's folder can be written<?= $outside ? ', outside the website' : ', inside the website behind a deny-all rule' ?></div>
    <div><?= $ok(smtp_password() !== null) ?> The mailbox password is set (wishlist-config.php)</div>
    <?php foreach ($reach as $port => $r): ?>
      <div><?= $ok($r) ?> The mail server <?= e(SMTP_HOST) ?> answers on port <?= $port ?></div>
    <?php endforeach; ?>
    <div><?= $ok(is_file(__DIR__ . '/wishlist-check.php') === false) ?> wishlist-check.php is not on the website<?= is_file(__DIR__ . '/wishlist-check.php') ? ' (delete it)' : '' ?></div>
  </div>
  <p class="muted">To check that sending really works, use "Send a test" on the Email everyone tab.</p>
<?php endif; ?>
<?php endif; ?>
</main>
</body>
</html>
