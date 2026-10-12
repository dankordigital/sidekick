<?php
/*
 * Sidekick's wishlist (the form on index.html, #wishlist).
 *
 * Upload next to index.html. It needs only PHP: no database. The list is a
 * CSV file in a private folder, `sidekick-wishlist`, made next to the
 * website's folder (outside it, so nobody can open it from the web), or,
 * where that isn't allowed, inside it behind a "deny all" .htaccess.
 * Open list.csv with FileZilla (or any spreadsheet) to see who signed up.
 *
 * Signing up puts the address on the list and emails "Got your email!
 * We'll remind you when Sidekick comes out." (the owner's words), with a
 * link that removes it again.
 *
 *   POST  wishlist.php            email, devices, t (page time), website (a trap)
 *   GET   wishlist.php?remove=…   removes, then back to the page
 *
 * Emails go through OVHcloud's mail server (ssl0.ovh.net), logged in as
 * FROM, like a mail app: PHP's own mail() is often dropped by the hosting.
 * The mailbox password lives in wishlist-config.php next to this file
 * (never in git; see wishlist-config.example.php). Without it, mail() is
 * tried. Every failure is written to sidekick-wishlist/mail.log.
 *
 * On localhost (php -S localhost:8000) emails aren't sent: they're saved
 * in sidekick-wishlist/outbox, so the whole flow can be tried offline.
 */

// The address the emails come from: a mailbox you made for
// getsidekick.app in OVHcloud (Web Cloud → Emails).
const FROM = 'info@getsidekick.app';
const FROM_NAME = 'Sidekick';
const SITE = 'https://getsidekick.app';
// Also tell FROM about each new sign-up ("New on the wishlist: …").
const NOTIFY_OWNER = true;

// OVHcloud's outgoing mail server. Tried in order: SSL on 465, then
// STARTTLS on 587 (some hostings block one of them). Port 993 is IMAP:
// it's for reading the mailbox and can't send.
const SMTP_HOST = 'ssl0.ovh.net';
const SMTP_PORTS = [465, 587];

const MAX_PER_HOUR = 5;        // sign-ups per visitor (by a hash of their IP)

ini_set('display_errors', '0');
header('X-Robots-Tag: noindex, nofollow');
header('Cache-Control: no-store');

$local = in_array($_SERVER['SERVER_NAME'] ?? '', ['localhost', '127.0.0.1'], true);
$site = $local ? 'http://' . $_SERVER['HTTP_HOST'] : SITE;

function data_dir(): string {
    $outside = dirname(__DIR__) . '/sidekick-wishlist';
    if ((is_dir($outside) || @mkdir($outside, 0700)) && is_writable($outside)) {
        return $outside;
    }
    $inside = __DIR__ . '/sidekick-wishlist';
    if (!is_dir($inside) && !@mkdir($inside, 0700)) {
        throw new RuntimeException('No folder for the wishlist');
    }
    if (!file_exists("$inside/.htaccess")) {
        file_put_contents("$inside/.htaccess",
            "<IfModule mod_authz_core.c>\n  Require all denied\n</IfModule>\n"
            . "<IfModule !mod_authz_core.c>\n  Deny from all\n</IfModule>\n");
    }
    return $inside;
}

function reply(int $code, array $body): void {
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($body);
    exit;
}

function back(string $state): void {
    global $site;
    header('Location: ' . $site . '/?wishlist=' . $state . '#wishlist', true, 303);
    exit;
}

const COLUMNS = ['email', 'devices', 'joined', 'token', 'emailed'];

/** Runs [$change] on the list (email => row) under a lock, and saves it. */
function with_list(callable $change) {
    $dir = data_dir();
    $lock = fopen("$dir/.lock", 'c');
    flock($lock, LOCK_EX);
    try {
        $rows = [];
        $file = "$dir/list.csv";
        if (is_readable($file) && ($h = fopen($file, 'r'))) {
            fgetcsv($h, 0, ',', '"', '');  // the header
            while (($r = fgetcsv($h, 0, ',', '"', '')) !== false) {
                if (count($r) === count(COLUMNS)) {
                    $row = array_combine(COLUMNS, $r);
                    $rows[$row['email']] = $row;
                }
            }
            fclose($h);
        }
        $result = $change($rows);
        $tmp = "$file.tmp";
        $h = fopen($tmp, 'w');
        fputcsv($h, COLUMNS, ',', '"', '');
        foreach ($rows as $row) {
            fputcsv($h, array_values($row), ',', '"', '');
        }
        fclose($h);
        rename($tmp, $file);
        @chmod($file, 0600);
        return $result;
    } finally {
        flock($lock, LOCK_UN);
        fclose($lock);
    }
}

/** At most MAX_PER_HOUR tries an hour from one visitor. Only a salted hash
 *  of the IP is kept, and only for the hour. */
function allowed(): bool {
    $dir = data_dir();
    $saltFile = "$dir/.salt";
    if (!file_exists($saltFile)) {
        file_put_contents($saltFile, bin2hex(random_bytes(16)));
    }
    $key = hash('sha256', file_get_contents($saltFile) . ($_SERVER['REMOTE_ADDR'] ?? ''));
    $file = "$dir/limits.json";
    $h = fopen($file, 'c+');
    flock($h, LOCK_EX);
    $limits = json_decode(stream_get_contents($h) ?: '{}', true) ?: [];
    $now = time();
    foreach ($limits as $k => $times) {
        $limits[$k] = array_values(array_filter($times, fn($t) => $now - $t < 3600));
        if (!$limits[$k]) unset($limits[$k]);
    }
    $ok = count($limits[$key] ?? []) < MAX_PER_HOUR;
    if ($ok) $limits[$key][] = $now;
    ftruncate($h, 0);
    rewind($h);
    fwrite($h, json_encode($limits));
    flock($h, LOCK_UN);
    fclose($h);
    return $ok;
}

function send_welcome(string $email, string $token): bool {
    global $local, $site;
    $remove = "$site/wishlist.php?remove=$token";
    $subject = 'Got your email!';
    $body = "Hi!\r\n\r\n"
        . "Got your email! We'll remind you when Sidekick comes out.\r\n\r\n"
        . "Sidekick makes your phone and computer work as one: send files both ways, share\r\n"
        . "your clipboard, use your phone as a touchpad, mirror its screen and more, on\r\n"
        . "Windows, Mac, Android and iPhone. Free, with no account.\r\n\r\n"
        . "That's the only email you'll get until then. We never share your address.\r\n\r\n"
        . "Changed your mind? Remove your email from the list:\r\n"
        . "$remove\r\n\r\n"
        . "Sidekick\r\ngetsidekick.app\r\n";
    $html = welcome_html($remove);
    if ($local) {
        $out = data_dir() . '/outbox';
        @mkdir($out, 0700);
        file_put_contents("$out/" . date('Ymd-His') . "-$email.html", str_replace('cid:header', '/website/email-header.png', $html));
        return file_put_contents("$out/" . date('Ymd-His') . "-$email.txt", "To: $email\r\nSubject: $subject\r\n\r\n$body") !== false;
    }
    return send_mail($email, $subject, $body, FROM_NAME, FROM, ['List-Unsubscribe: <' . $remove . '>'], $html);
}

/** The designed version of "Got your email!": the header image (logo on
 *  Sidekick's purple), the message, a button to the site, and the remove
 *  link. Tables and inline styles: what every email app understands. */
function welcome_html(string $remove): string {
    $site = htmlspecialchars(SITE);
    $remove = htmlspecialchars($remove);
    $font = "font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif";
    // Attached inline when the file is on the hosting (mime_body), else
    // loaded from the site.
    $img = is_file(__DIR__ . '/website/email-header.png') ? 'cid:header' : "$site/website/email-header.png";
    return <<<HTML
<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light only"><title>Got your email!</title></head>
<body style="margin:0;padding:0;background:#f1edf8">
<div style="display:none;max-height:0;overflow:hidden">We'll remind you when Sidekick comes out.</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f1edf8"><tr><td align="center" style="padding:24px 12px">
<table role="presentation" width="600" cellpadding="0" cellspacing="0" style="width:100%;max-width:600px;background:#ffffff;border-radius:24px;overflow:hidden">
<tr><td bgcolor="#2a1257" align="center" style="background:#2a1257"><a href="$site" style="color:#ffffff;text-decoration:none"><img src="$img" width="600" alt="Sidekick" style="display:block;width:100%;height:auto;border:0;background:#2a1257;color:#ffffff;$font;font-size:28px;font-weight:800;line-height:80px;text-align:center;text-decoration:none"></a></td></tr>
<tr><td style="padding:36px 40px 8px;$font;color:#1d1530">
<h1 style="margin:0 0 12px;font-size:30px;line-height:1.2;font-weight:800">Got your email!</h1>
<p style="margin:0 0 16px;font-size:17px;line-height:1.55;color:#3d3550">We'll remind you when Sidekick comes out.</p>
<p style="margin:0 0 16px;font-size:16px;line-height:1.55;color:#5d5670">Sidekick makes your phone and computer work as one: send files both ways, share your clipboard, use your phone as a touchpad, mirror its screen and more, on Windows, Mac, Android and iPhone. Free, with no account.</p>
<p style="margin:0 0 22px;font-size:16px;line-height:1.55;color:#5d5670">Changed your mind? Cancel, and your email is taken off the list right away.</p>
</td></tr>
<tr><td align="center" style="padding:0 40px 30px">
<table role="presentation" cellpadding="0" cellspacing="0"><tr><td align="center" bgcolor="#6a4cff" style="border-radius:14px;background:linear-gradient(100deg,#7b5cff,#c04fd8)">
<a href="$remove" style="display:inline-block;padding:15px 34px;$font;font-size:17px;font-weight:700;color:#ffffff;text-decoration:none;border-radius:14px">Cancel my sign-up</a>
</td></tr></table>
</td></tr>
<tr><td style="padding:0 40px 32px;$font;font-size:14px;line-height:1.5;color:#8a8399;border-top:1px solid #eee8f6">
<p style="margin:22px 0 0">That's the only email you'll get until then. We never share your address.</p>
</td></tr>
</table>
<p style="margin:18px 0 0;$font;font-size:13px;color:#a39cb3">Sidekick · <a href="$site" style="color:#a39cb3">getsidekick.app</a></p>
</td></tr></table>
</body></html>
HTML;
}

function mail_log(string $line): void {
    try {
        file_put_contents(data_dir() . '/mail.log', gmdate('Y-m-d H:i:s') . " $line\n", FILE_APPEND);
    } catch (Throwable $e) {
    }
    error_log("Sidekick wishlist: $line");
}

/** The mailbox password, from wishlist-config.php (not in git). */
function smtp_password(): ?string {
    $file = __DIR__ . '/wishlist-config.php';
    if (!is_readable($file)) return null;
    $config = include $file;
    $p = is_array($config) ? ($config['smtp_password'] ?? '') : '';
    return $p !== '' ? $p : null;
}

/** Sends a plain-text email: through OVHcloud's mail server when the
 *  password is set, otherwise with mail(). False (and a log line) if not. */
function send_mail(string $to, string $subject, string $body, string $fromName, string $replyTo, array $extra = [], ?string $html = null): bool {
    $subj = '=?UTF-8?B?' . base64_encode($subject) . '?=';
    $headers = array_merge(['From: ' . $fromName . ' <' . FROM . '>', 'Reply-To: ' . $replyTo, 'MIME-Version: 1.0'], $extra);
    if ($html === null) {
        $headers[] = 'Content-Type: text/plain; charset=UTF-8';
        $headers[] = 'Content-Transfer-Encoding: 8bit';
    } else {
        [$type, $body] = mime_body($body, $html);
        $headers[] = $type;
    }
    $password = smtp_password();
    if ($password !== null) {
        foreach (SMTP_PORTS as $port) {
            $error = smtp_send($to, $subj, $body, $headers, $password, $port);
            if ($error === null) return true;
            mail_log("SMTP (port $port) to $to failed: $error");
            // A refused password fails the same on every port.
            if (str_starts_with($error, 'login refused')) return false;
        }
        // Both ports blocked: mail() as a last try.
        $h = implode("\r\n", $headers);
        if (@mail($to, $subj, $body, $h, '-f' . FROM) || @mail($to, $subj, $body, $h)) return true;
        mail_log("mail() to $to failed too");
        return false;
    }
    // No password: PHP's mail(), first with the envelope sender, then without
    // (some hosts refuse the -f option).
    $h = implode("\r\n", $headers);
    if (@mail($to, $subj, $body, $h, '-f' . FROM) || @mail($to, $subj, $body, $h)) return true;
    mail_log("mail() to $to failed (no SMTP password set in wishlist-config.php)");
    return false;
}

/** Plain text and HTML together (the app shows what it can), with the
 *  header image attached inline so it shows even when web images are
 *  blocked. Returns [Content-Type header, body]. */
function mime_body(string $text, string $html): array {
    $alt = 'alt-' . bin2hex(random_bytes(8));
    $rel = 'rel-' . bin2hex(random_bytes(8));
    $part = fn(string $type, string $data) => "Content-Type: $type\r\nContent-Transfer-Encoding: base64\r\n\r\n"
        . chunk_split(base64_encode($data)) . "\r\n";
    $alternative = "--$alt\r\n" . $part('text/plain; charset=UTF-8', $text)
        . "--$alt\r\n" . $part('text/html; charset=UTF-8', $html) . "--$alt--\r\n";
    $image = @file_get_contents(__DIR__ . '/website/email-header.png');
    if ($image === false) {
        // No image on the hosting: the HTML without it.
        return ["Content-Type: multipart/alternative; boundary=\"$alt\"", $alternative];
    }
    $body = "--$rel\r\nContent-Type: multipart/alternative; boundary=\"$alt\"\r\n\r\n$alternative"
        . "--$rel\r\nContent-Type: image/png; name=\"sidekick.png\"\r\nContent-Transfer-Encoding: base64\r\n"
        . "Content-ID: <header>\r\nContent-Disposition: inline; filename=\"sidekick.png\"\r\n\r\n"
        . chunk_split(base64_encode($image)) . "\r\n--$rel--\r\n";
    return ["Content-Type: multipart/related; boundary=\"$rel\"; type=\"multipart/alternative\"", $body];
}

/** A small SMTP client: SSL on 465, STARTTLS on any other port, AUTH LOGIN
 *  as FROM. Null on success, else why. */
function smtp_send(string $to, string $subject, string $body, array $headers, string $password, int $port = 465): ?string {
    $ctx = stream_context_create(['ssl' => ['verify_peer' => true, 'verify_peer_name' => true, 'peer_name' => SMTP_HOST]]);
    $tls = $port !== 465;
    $s = @stream_socket_client(($tls ? 'tcp://' : 'ssl://') . SMTP_HOST . ':' . $port, $errno, $errstr, 15, STREAM_CLIENT_CONNECT, $ctx);
    if (!$s) return "can't connect to " . SMTP_HOST . ":$port: $errstr ($errno)";
    stream_set_timeout($s, 15);
    $read = function () use ($s): string {
        $all = '';
        while (($line = fgets($s, 1024)) !== false) {
            $all .= $line;
            if (strlen($line) < 4 || $line[3] === ' ') break;
        }
        return $all;
    };
    // [$label] names the step in the log: never the command itself, which
    // for the login steps is the address and password.
    $step = function (?string $cmd, string $want, string $label = '') use ($s, $read): ?string {
        if ($cmd !== null) fwrite($s, $cmd . "\r\n");
        $reply = $read();
        return str_starts_with($reply, $want) ? null : trim(($label !== '' ? "$label: " : '') . $reply);
    };
    $host = parse_url(SITE, PHP_URL_HOST) ?: 'localhost';
    // The message: dot-stuffed, CRLF line ends.
    $data = implode("\r\n", array_merge(["To: <$to>", "Subject: $subject", 'Date: ' . date('r'),
        'Message-ID: <' . bin2hex(random_bytes(12)) . '@' . $host . '>'], $headers)) . "\r\n\r\n"
        . preg_replace('/^\./m', '..', str_replace(["\r\n", "\n"], ["\n", "\r\n"], $body));
    $error = $step(null, '220', 'greeting')
        ?? $step("EHLO $host", '250', 'EHLO')
        ?? ($tls ? ($step('STARTTLS', '220', 'STARTTLS')
            ?? (@stream_socket_enable_crypto($s, true, STREAM_CRYPTO_METHOD_TLS_CLIENT) ? null : 'TLS handshake failed')
            ?? $step("EHLO $host", '250', 'EHLO after TLS')) : null)
        ?? $step('AUTH LOGIN', '334', 'AUTH')
        ?? $step(base64_encode(FROM), '334', 'login name')
        ?? (($e = $step(base64_encode($password), '235')) !== null ? 'login refused (check the password in wishlist-config.php): ' . $e : null)
        ?? $step('MAIL FROM:<' . FROM . '>', '250', 'MAIL FROM')
        ?? $step("RCPT TO:<$to>", '25', 'RCPT TO')
        ?? $step('DATA', '354', 'DATA')
        ?? $step($data . "\r\n.", '250', 'message');
    fwrite($s, "QUIT\r\n");
    fclose($s);
    return $error;
}

/** A short note to FROM about a new sign-up (never shown to the visitor). */
function notify_owner(string $email, array $devices, bool $sent): void {
    global $local;
    $count = with_list(fn(array &$rows) => count($rows));
    $subject = "New on the wishlist: $email";
    $body = "$email joined the Sidekick wishlist.\r\n"
        . 'Devices: ' . ($devices ? implode(', ', $devices) : 'not picked') . "\r\n"
        . "People on the list now: $count\r\n"
        . ($sent ? '' : "\r\nThe \"Got your email!\" email couldn't be sent to them.\r\n")
        . "\r\nThe whole list: sidekick-wishlist/list.csv on the hosting (FileZilla).\r\n";
    if ($local) {
        $out = data_dir() . '/outbox';
        @mkdir($out, 0700);
        file_put_contents("$out/" . date('Ymd-His') . '-owner.txt', "To: " . FROM . "\r\nSubject: $subject\r\n\r\n$body");
        return;
    }
    send_mail(FROM, $subject, $body, FROM_NAME . ' wishlist', $email);
}

function by_token(array &$rows, string $token): ?string {
    if (!preg_match('/^[a-f0-9]{32}$/', $token)) return null;
    foreach ($rows as $k => $row) {
        if (hash_equals($row['token'], $token)) return $k;
    }
    return null;
}

// wishlist-check.php loads the functions above without handling a request.
if (defined('WISHLIST_LIB')) return;

try {
    if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['remove'])) {
        $token = (string) $_GET['remove'];
        with_list(function (array &$rows) use ($token) {
            $k = by_token($rows, $token);
            if ($k !== null) unset($rows[$k]);
        });
        back('removed');
    }

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        header('Location: /#wishlist', true, 303);
        exit;
    }

    // Bots fill in the hidden "website" field, or post the instant the page
    // loads: they're told it worked, and nothing happens.
    $loaded = (int) ($_POST['t'] ?? 0) / 1000;
    if (($_POST['website'] ?? '') !== '' || $loaded <= 0 || time() - $loaded < 2) {
        reply(200, ['ok' => true, 'status' => 'joined']);
    }

    $email = strtolower(trim((string) ($_POST['email'] ?? '')));
    if (strlen($email) > 254 || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        reply(400, ['ok' => false, 'error' => 'email']);
    }
    $devices = array_values(array_intersect(
        explode(',', (string) ($_POST['devices'] ?? '')),
        ['Windows', 'Mac', 'Android', 'iPhone']
    ));

    if (!allowed()) {
        reply(429, ['ok' => false, 'error' => 'busy']);
    }

    [$status, $token] = with_list(function (array &$rows) use ($email, $devices) {
        if (isset($rows[$email])) {
            if ($devices) $rows[$email]['devices'] = implode(' ', $devices);
            return ['already', null];
        }
        $token = bin2hex(random_bytes(16));
        $rows[$email] = ['email' => $email, 'devices' => implode(' ', $devices), 'joined' => gmdate('Y-m-d H:i:s'),
                         'token' => $token, 'emailed' => ''];
        return ['joined', $token];
    });

    // On the list either way; the email says so. If it can't be sent now,
    // the address stays on the list (list.csv shows "emailed" empty).
    $sent = false;
    if ($token !== null) {
        $sent = send_welcome($email, $token);
        if ($sent) {
            with_list(function (array &$rows) use ($email) {
                if (isset($rows[$email])) $rows[$email]['emailed'] = gmdate('Y-m-d H:i:s');
            });
        } else {
        }
        if (NOTIFY_OWNER) notify_owner($email, $devices, $sent);
    }
    reply(200, ['ok' => true, 'status' => $status, 'emailed' => $sent]);
} catch (Throwable $e) {
    error_log('Sidekick wishlist: ' . $e->getMessage());
    reply(500, ['ok' => false, 'error' => 'server']);
}
