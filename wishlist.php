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
        file_put_contents("$out/" . date('Ymd-His') . "-$email.html", str_replace('cid:header', 'data:image/jpeg;base64,' . header_image(), $html));
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
    return <<<HTML
<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light only"><title>Got your email!</title></head>
<body style="margin:0;padding:0;background:#f1edf8">
<div style="display:none;max-height:0;overflow:hidden">We'll remind you when Sidekick comes out.</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f1edf8"><tr><td align="center" style="padding:24px 12px">
<table role="presentation" width="600" cellpadding="0" cellspacing="0" style="width:100%;max-width:600px;background:#ffffff;border-radius:24px;overflow:hidden">
<tr><td bgcolor="#2a1257" align="center" style="background:#2a1257"><a href="$site" style="color:#ffffff;text-decoration:none"><img src="cid:header" width="600" alt="Sidekick" style="display:block;width:100%;height:auto;border:0;background:#2a1257;color:#ffffff;$font;font-size:28px;font-weight:800;line-height:80px;text-align:center;text-decoration:none"></a></td></tr>
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
    $body = "--$rel\r\nContent-Type: multipart/alternative; boundary=\"$alt\"\r\n\r\n$alternative"
        . "--$rel\r\nContent-Type: image/jpeg; name=\"sidekick.jpg\"\r\nContent-Transfer-Encoding: base64\r\n"
        . "Content-ID: <header>\r\nContent-Disposition: inline; filename=\"sidekick.jpg\"\r\n\r\n"
        . chunk_split(header_image()) . "\r\n--$rel--\r\n";
    return ["Content-Type: multipart/related; boundary=\"$rel\"; type=\"multipart/alternative\"", $body];
}

/** The email's header image (website/email-header.png as a JPEG), kept
 *  inside this file so the email never depends on another upload. */
function header_image(): string {
    return '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';
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
