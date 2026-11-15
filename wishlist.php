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
        . "Sidekick makes your phone and computer work as one: send files both ways, use\r\n"
        . "your phone as a touchpad and keyboard, find your phone, and keep everything\r\n"
        . "you shared in one place. On Windows, Mac, Android and iPhone. Free, with no\r\n"
        . "account.\r\n\r\n"
        . "Try the demo in your browser: " . SITE . "/preview\r\n\r\n"
        . "That's the only email you'll get until then. We never share your address.\r\n\r\n"
        . "Changed your mind? Remove your email from the list:\r\n"
        . "$remove\r\n\r\n"
        . "Sidekick\r\ngetsidekick.app · " . FROM . "\r\n";
    $html = welcome_html($remove);
    if ($local) {
        $out = data_dir() . '/outbox';
        @mkdir($out, 0700);
        file_put_contents("$out/" . date('Ymd-His') . "-$email.html", str_replace(['cid:header', 'cid:logo'], ['data:image/jpeg;base64,' . header_image(), 'data:image/png;base64,' . logo_image()], $html));
        return file_put_contents("$out/" . date('Ymd-His') . "-$email.txt", "To: $email\r\nSubject: $subject\r\n\r\n$body") !== false;
    }
    return send_mail($email, $subject, $body, FROM_NAME, FROM, ['List-Unsubscribe: <' . $remove . '>'], $html);
}

/** The designed version of "Got your email!", in Sidekick 4.0's look (dark,
 *  white pill buttons, one word in an app colour, like the website): the
 *  header image, the message, Try the demo, Cancel my sign-up (the remove
 *  link). Tables and inline styles: what every email app understands. */
function welcome_html(string $remove): string {
    $site = htmlspecialchars(SITE);
    $remove = htmlspecialchars($remove);
    $f = EMAIL_FONT;
    $chips = email_chips(['Send files', 'Touchpad', 'Find your phone', 'No account']);
    $inner = <<<HTML
<tr><td style="padding:34px 36px 6px;$f;color:#f2f2f2">
<h1 style="margin:0 0 14px;font-size:32px;line-height:1.15;font-weight:800;letter-spacing:-0.5px;color:#f2f2f2">Got your <span style="color:#5b9dff">email!</span></h1>
<p style="margin:0 0 16px;font-size:18px;line-height:1.5;color:#f2f2f2">We'll remind you when Sidekick comes out.</p>
<p style="margin:0 0 18px;font-size:16px;line-height:1.6;color:#a1a1a6">Sidekick makes your phone and computer work as one: send files both ways, use your phone as a touchpad and keyboard, find your phone, and keep everything you shared in one place. On Windows, Mac, Android and iPhone. Free, with no account.</p>
</td></tr>
<tr><td style="padding:0 36px 6px">$chips</td></tr>
<tr><td style="padding:22px 36px 30px">
<table role="presentation" cellpadding="0" cellspacing="0"><tr>
<td bgcolor="#f0f0f0" style="border-radius:999px;background:#f0f0f0"><a href="$site/preview" style="display:inline-block;padding:14px 26px;$f;font-size:16px;font-weight:700;color:#141414;text-decoration:none;border-radius:999px">Try the demo</a></td>
<td width="10" style="width:10px"></td>
<td style="border-radius:999px;border:1px solid #3a3a3c"><a href="$remove" style="display:inline-block;padding:13px 22px;$f;font-size:16px;font-weight:600;color:#f2f2f2;text-decoration:none;border-radius:999px">Cancel my sign-up</a></td>
</tr></table>
</td></tr>
<tr><td style="padding:0 36px 30px;$f;font-size:14px;line-height:1.55;color:#8a8a8f;border-top:1px solid #2a2a2a">
<p style="margin:22px 0 0">That's the only email you'll get until then. We never share your address. Changed your mind? Cancel, and your email is taken off the list right away.</p>
</td></tr>
HTML;
    return email_shell('Got your email!', "We'll remind you when Sidekick comes out.", $inner);
}

/** The font every email uses: Inter where the email app loads it, else the system's. */
const EMAIL_FONT = "font-family:Inter,-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif";

/** Small labels under the welcome text, like the website's chips. */
function email_chips(array $labels): string {
    $f = EMAIL_FONT;
    $cells = '';
    foreach ($labels as $l) {
        $cells .= '<td style="padding:0 6px 6px 0"><span style="display:inline-block;padding:6px 12px;border-radius:999px;background:#262626;'
            . $f . ';font-size:13px;font-weight:500;color:#f2f2f2;white-space:nowrap">' . htmlspecialchars($l) . '</span></td>';
    }
    return '<table role="presentation" cellpadding="0" cellspacing="0"><tr>' . $cells . '</tr></table>';
}

/** Every email's frame, in the 4.0 look: a near-black page, the header image
 *  (the "sk" icon and the wordmark), a dark card with [inner] (table rows),
 *  and the signature under it. */
function email_shell(string $title, string $preheader, string $inner): string {
    $site = htmlspecialchars(SITE);
    $title = htmlspecialchars($title);
    $preheader = htmlspecialchars($preheader);
    $f = EMAIL_FONT;
    $footer = email_footer();
    return <<<HTML
<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="dark"><meta name="supported-color-schemes" content="dark"><title>$title</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
<style>:root{color-scheme:dark}body{margin:0;padding:0;background:#0a0a0a}a{color:#5b9dff}</style></head>
<body bgcolor="#0a0a0a" style="margin:0;padding:0;background:#0a0a0a">
<div style="display:none;max-height:0;overflow:hidden">$preheader</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#0a0a0a" style="background:#0a0a0a"><tr><td align="center" style="padding:28px 12px">
<table role="presentation" width="600" cellpadding="0" cellspacing="0" bgcolor="#1c1c1c" style="width:100%;max-width:600px;background:#1c1c1c;border-radius:26px;overflow:hidden;border:1px solid #262626">
<tr><td bgcolor="#121212" align="center" style="background:#121212"><a href="$site" style="color:#ffffff;text-decoration:none"><img src="cid:header" width="600" alt="Sidekick" style="display:block;width:100%;height:auto;border:0;background:#121212;color:#ffffff;$f;font-size:28px;font-weight:800;line-height:110px;text-align:center;text-decoration:none"></a></td></tr>
$inner
</table>
{$footer}
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
        . chunk_split(header_image()) . "\r\n"
        . "--$rel\r\nContent-Type: image/png; name=\"sidekick-logo.png\"\r\nContent-Transfer-Encoding: base64\r\n"
        . "Content-ID: <logo>\r\nContent-Disposition: inline; filename=\"sidekick-logo.png\"\r\n\r\n"
        . chunk_split(logo_image()) . "\r\n--$rel--\r\n";
    return ["Content-Type: multipart/related; boundary=\"$rel\"; type=\"multipart/alternative\"", $body];
}

/** The signature under every email: the new "sk" icon (attached inline as
 *  cid:logo), the name, the site and the mailbox, on the dark page. */
function email_footer(): string {
    $site = htmlspecialchars(SITE);
    $from = htmlspecialchars(FROM);
    $f = EMAIL_FONT;
    return <<<HTML
<table role="presentation" cellpadding="0" cellspacing="0" style="margin:24px auto 4px"><tr>
<td valign="middle" style="padding-right:12px"><a href="$site"><img src="cid:logo" width="44" height="44" alt="sk" style="display:block;border:0;border-radius:10px"></a></td>
<td valign="middle" style="$f;text-align:left">
<div style="font-size:15px;font-weight:800;color:#f2f2f2">Sidekick</div>
<div style="font-size:13px;line-height:1.5;color:#8a8a8f"><a href="$site" style="color:#5b9dff;text-decoration:none">getsidekick.app</a> · <a href="mailto:$from" style="color:#8a8a8f;text-decoration:none">$from</a></div>
</td></tr></table>
<div style="$f;font-size:12px;line-height:1.5;color:#5c5c60;margin:10px 0 0">Made with &#9829; in Poland</div>
HTML;
}

/** The signature's icon (the new "sk", Dusk, at 96 px), inside this file
 *  like the header. */
function logo_image(): string {
    return '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';
}

/** The email's header image (website/email-header.png as a JPEG: the "sk"
 *  icon and the wordmark on a dark glow), kept inside this file so the
 *  email never depends on another upload. */
function header_image(): string {
    return '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAQDAwQDAwQEBAQFBQQFBwsHBwYGBw4KCggLEA4RERAOEA8SFBoWEhMYEw8QFh8XGBsbHR0dERYgIh8cIhocHRz/2wBDAQUFBQcGBw0HBw0cEhASHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBz/wgARCAG4BLADASIAAhEBAxEB/8QAHAABAQEAAwEBAQAAAAAAAAAAAAECBQYHBAMI/8QAGgEBAQEBAQEBAAAAAAAAAAAAAAECAwQFBv/aAAwDAQACEAMQAAAB8RAAAAAAAFKIACrKgoFqgCUUCqtAKUKCgoFqgoC0soCqCiqQAUBKAUBKAEJURRFRJRFElRlRBEUSUklhFglSZWVFglRJSSWVFglJAJRJRABUWSAsFgAAAAAAAAAAAACy2AAoFCUWglAstAKUoqgLQoKBSiqAtCgqgKCiiwAKspBSxURQEABACVEmoRUQEUZVGVElElSZWEUSUmVhFglglJlZUWCUkBFhFgAlVBCWWAAAAAAAAAAAABSiAAqiLKBSgLQCgpaoC0BSgUqqFCgooAqgqrKAsSiigsRSyrEWAsRYBKEAJRJURYRUSaiSUSVEWEmomVElElGViRYJYJYkWVFhFiAQEWAEWAJBQAAAAAAAAAAClgAKogoFCgUoKCy0soLQCltAoKWqAoKCqKSqopKBUpRKpKSgCxFLKQlRFEVEBFRFGVRJqEVGVGViRYRYSUSUSUklGViRYRYRYklVARYiUSUQAVFkJSQUAAAAAAAAALYAAKAKUBQLLSgLQoLQClqgoKVQqgq1KKoKKUCwUopKQCmtGH6j8n61fxftI/NvOUVLFRFGVRFhFRFGVRlSSUSahlRJSZVGZqElVJSSWEWJFhFhJqJJVSUQIlglgAlVBEWWAAAAAAAAAUWAAUAtALKC0soFKClUClKqylFCrUoqqAKKqgKqkqrKQKs5XfdfqePieQ/efd8ix11UOojrUXrc06/h8HLOPXpPGekdO/P3iFfIxFRFS5USUkVGVGVkRSSUZmoSahJqJmahJqElJlZUWJFhFhJqJlZSUkBFhFgFRZIlEFAAAAAAALLYAAoBVABRVKBSgstKoFKoFqqSrQpKqlAtFSlULKoAqrLF2d55CP2fxg30B1EdQvUHUHUanV8X378m/MW8fjfMEJRFRlqEmoRUZUmZoZmoRYSaiZWEmomWskmoSUmVlQJASUmVhFlRYiUSUQAVBJFlAAAAAABVCACgAtAKUqgUoCirQUsoq1KCraKC2qBQqkoqqSkpSihUr6fn+3pO+w/ZfLB1EdQvU3h1B1Gp1ab8/Rtvy9PN/l5D4Py3jizEioiiSpJNDM1CLCKMzUMqkyqszUSSjKxJNQzNQkpMzUJKskokpMzUIKgRLCLABLESlgsAAAAAWWwABQCqAUWWlBZaFoUUoUFpSlFpQWlUlFVQVRQVRVKiWlFiff8AD9/Sd5H7LwCOo53HXgnaeDz19K/TPcfy2fEeD9a8y+/6fk1y299eJ23x7NXXm351x/Jcb+f8Ic8gRZEURYSaRmahJqJJqGWoZmokmoZmpZJUZWWSaySUSUmZZSWIlhJqJJZSUkBAQAVBJFlAAAAAUWALKALLQFFUoLQoFUoLQtKtAKqqUKKpKtpQKpSlQs0soFSqQ+74vu6u8I/Y+QZvX1juny/V+HrHFdO3ru/JdO7jidO5L6uV1XU+0+K768ftv6/0mm/L08343k+N+R86KxmKiLCKMqiAikzNDM1CSkzNQysSTUMzUSSjM1LMzUJKMzUTKyyLCLEksIKixEsEsAEsEpIKAAAWWwABQCqBZRZaUpQUpRFW0WhSilWlBRVWhVWUFVVJRVFVYFWVYKlfd8P3dHdh+z4CuvdvTurfF+Tz3v5fqfOzwnNlHWuwLxnjnvfmHs9XV9N+r6TbXm35rxvJ8Z8/5kVnMmhlUkUslJJqEmpElEmomVhJqJJVYaykmoZmoklhJVmZqGViTOoSVZJRJYkllJSQElEAlVBEFgAAClgAoAstAUVQlLSyqLYLSlKFstqgq0sopbSgtqgqrKsSqpSiwLKsopK+z4/q3e8j9ph9PzJ19i7P/Ov0/Cn9BcR458vC+w9g8A1nfqXy+d7nX3b4/Ft+TP0Zb39Fq683Ty/jvv8Ah4fIipmSoiiTUiKJKMtQysSLCTUTKwk1EmdQysskozKTM1DM1LMrCSxJLBLLIsJLEgqBEsIsAqLJEsAoACiwBQCqBZRZaWWxQoqimpRSlKVVUpVoUWaUWlFUKVRQWVRSpVBSVSH6YL6C+b6f2uhq9Wm/P0bb8vRtrzbum/L0bb8222vL0fpPk8u/LfxrXxIqIoiyIokoiySKMzQzNRJKMzUTKypNRMzUMzUszNQzNRMzUszNQksSTWSCySiZ1EkspLESiSwASwSkgoBZbAAKAWgFBSxVpZRZaFqiqUFqltFKWhRS1VFlVZSlUUUUWWiWgUlUlKl53sfQOw/a32DX5/v9Tu235ujbfm2035ejbfm2215ejbHl3+3Sf26Znxwb8AAQlEVElElElJJqElGZqJlYSaiZmpWZqJmahJZZmaiSWGZqWZWEliZWVFiSUmZqEFQJAQCVUEQWALLYAKALLQoFUJbLVFUCrSy0pVspRVstKLbLSlqhSqspQrUsqgsstEqirNSykKSqS36/kLyf6cRda5m8Kl5u8IxecvBXN5z8+HYch8EszFJFRFkoARFEmokmpEWEWVJqSZWVJSZmoZWJJZWViSWJM6lZWJM6iZmpUliTOoSVZJYSWJBUWIlhFgFQRFlgFFgCygVQLKLLYLVBRVFWyizVLLSrSy0oWy2qoLaqgqqCitSqLKssKSrKqkqkKZqyyiyhCkpWQKpAShBURRFRARYBCUSUmVhFhJqJmahJZZlYSWJJrNklhJZZmaiTOoZmpZmUTOomRZJRJYkllJYiWCWAEWIlgFUWAKAVQKCy2LLVsostLLVFWy1QWy1S0stULbLVKqgvOekS+OX2hl4vfZ6vi99nHjL0Ds6+M32Wx4y9k6mvSL7Jc3xq+yDxu+yfJL5M7BwDR37s2Z449jR45fYkvjt9hseOvTLL5m9hHjz0nqM1wl9hTPjz2HrUvQ3r+jx57CPHnaev51809P5O58dexDx2exDx17F1eOiPYx429j88OvPReePG57Ks8azy/E51lZUliSWJJYZmpZlYkzqVmaiZllklhJYkllRYkliSWCWUCSWACWUlkgaUIBQLLQFBRY1LSy0sopVLVLSy0s0KUq0strUostt+j5+4R/R3LHjDrx2F4J9G3uc8Nq896p4r7VAZn4+U+seT6vrgzAAMfz9/QnWrrqHqnl3qIEydI6O17e8Rq9+/Tyf1iXtYvPpPEeiftNbFy8E9t/lPPX+tv0/H9tcgPDvRumeu56Ua5gAPKfVfKc79XGsPAvffjmt/SXLj+Q8ll8W/Gzj65LEkssysJLEmdSzM1DM1LMyxJLEzNSpLEzNZEssiwksSCoEgIBLKCIXWQAKBZaAosoLZaWWqKpRZatlsUttlqlFlqltUKW28rxVj+y/3/lTtnne/vCrHub5Psw/LyT2CV4F794d7jqhiZ8h9e8a1fZxmeadA/ofOteNe1SyPk+vjpOj+k+cejqCfH8HFdGb9Ovmn6HO8z5l6bL2sXmY2AeZ+Ff1B/MGPT/W31fJ9e/MB5b6l5R6vnYaw8L90/Ca/l39f6KY6/wA88h7v56etjpwGDYH8vf1D4Zjp5Us5+iZ1EysJnUszNRJnUszLCSxMzUszNQzLLJLEksJKsksJLEgqBIsIBKqCJZdZAAoFlpZQLKC0qiqWllprOqUSltalpZSlpZatlVZbb2vqnaMv6oxxV8rlLxQ5pwuTnMdY8st/b3f+dfcNOacK5zmfGvTPLt69rcMxnmXDDmXDfgdg86+HxnXT3T0Xy7vEzzLhkz93D/UX8v0tOuclxkmu+uHXPTuc6bw+enu7h158x/NvvXmk6er/AGde+m8+YcOPLfS/LukY7/1O6D2TfDmnDjmHDjmPKO/+bTfsLhrccx4V65/OGen9T3pvM658z1z6h/KM5nh+PryDM1lJNSzMsSSwmdSzM1EzNZqSxMzUszKJnWUgsksJNZSCoESwgAqCQNQBZQBZaWUWWxZSiqKtlpZatlspRZbbZbFLbZaVRRVLbZRZVpVWWKFpZQlpZVllWWBZoMqJaWJTNUlWWAlFgJQgBSAEoiyAIsICLCLEksqLEksJLEksrM1EksTM1mySxJnUrMsSSyySwksTIsksGdRJLKixEsIsAqCQNQBZQCillFlsWWqC2WllpSrZbLZaWW22Uoq2WrZSi2lWgtlVZValgFtllWWVSWiWiFlmllyWWVZZVlyCVZZVliUgJVlgIAACUEiwSiSwSwSxGdSpLCTWUZ1EzLCSyySxJnWbJLCSyySxMyxJLKksSSyyAksSSyksRLBLAKgkDUAWUCqBZRZbFlqgtlpZaoq2Wy2WlWllKLbZatlKW1ZVoLZVoW2WAW2WVZZaJaJaIozpZYWWVZc1ZZQiiVZYCAlogIAACUBLEAgICBJLCAkssksJLEmdZsksSSyzMsJLLJLEmdZsksJLEkssgJLEkspLESwSwAgQNQBZQKoFlFlsWWqC2WllqirZbLZatlpZSltazqllq2VVlW2UWVaUWVVllWWWiWiWiWiWjNWWFlzVJaJQijNUgIWVQgIAACUBLAEgICBJKMrCSyySwksSZ1LMrEmdZsksJnUTMssmdRMyypKTMsSLKksSSwSyxLBLACBA1AFlAqgWUWWxZaoLZaospbVlstlq2WlKtlVqWllq2VVlLZVWVbZRZVWWVZZaJbZZRZQlozaIUzaJaJQijNogIWWUAIACUAACBIBLCAgSSwksskozLEkssksSZ1mySwksszLEksJnWbIsTMsEssksSSwSyxLBLACBA1AFlAqgWUWWxZaoLZaostltWWy2WrZatlFlttlpZatlVZS2VaFtlFlVZZVlloltllWWVZc0JaIozaJaJQijNogIUlACFlgFAgAIEgEsEsEsSSwgsyDMsSSyySxJLDMssksTMssksSSypLEzLBLLJLEksEspLESwAgQNQBZQKoFlFlsWWqKtlKLLZbVlstlq2WrZaWVbZaoq2VaUWVaFtlFlVSVqWUJbZZVllWXNCWiKM2iWiVZcglogIolCAFlgFASwAiyILEsEsEsSSwgsyDM1lGdZsksSSwzLLJLEzNZsksJLLJLEzLBLLJLEksEspLESwAgQNQBQCqBQUsUqirQostLVLLSrSqKtFtKoq0W0KFoW0FFoltJQltJVJVM0JaIozaJaJVMglogIolCAFIBQEAIQILEBAQSQIEyKmRGSyQSQMwskEmSyQJCyQTMBCyQSQEKQRAAgT//EADQQAAAFAwIEBQQABQUAAAAAAAACAwQFAQYVEBYRIDRwEhMUITUwMUBgIiQyMzYlJpCgsP/aAAgBAQABBQL/AKxnAeAw8sw8s48s48s48s48sw8Bhw7FNmKjgJxyBAVFMn0zIpmCkcicOGR0OwzBr56n4D5t5B+wjJPym34DxLzW3YMtONft+Dw4g1PCbsE3pxX/AAnNODjsE06n6HgNQn0XvV9gmfVfQt0tDxju3my4fRLhhTnfdZ2CZ9Vyow71elbefUo4aLtRbXxwuT45Bou5GLejGPOV/wBZ2CZ9VyQcWRFHQxSnKzQQbFFy/Gw7T0jETr30zbkf9Z2CZ9TrX7NzUM3EjR5VDPu2hbarU0eHzT1hQY1CleuqvXXJIdb2CZ9TyQ02VqUihVChdum5TjGOPR1lEFHDGnLIdb2CadTrSla1bQSHoG9vqM3HJNODNGyahVUxNsvTuOSQ63sE06nVuuZssxnWzumj2SbsSw7w7xt4qC4eBo+3nfFHxUDpAjtA6Zkj6v8ArewTf2X5OHEJrKpCrtyenAcB4KClBwHgoKF5XleLvsESvhP+DQKm8anYNA/mI/gO1PJa9hI9fhX8Cad+KvYVvIAhyqfVUVIjR5M+1ffsPSvAFdLEFJBxQZJwMm4GUcDKuBlXAyzgZZyMs5FZR1UHfOTita1/4yY2Idyp07BPUuwBsAbAGwRsEbBDW2fUyuwRsIbCFbC4Ug7ezNNhDYQ2GNhjYYWsVYtH8I9jdIS2sw12GNiDYg2INiDYg2IJK0ceyjbRyDLYg2IJS1KRjKKjTyrzYo2KNiiatykO2pY3GmxRsUbFE3D4dZBuo5VbWU6UpsUbFGxRsQbEGxA5tz08vsQbEGxBMxmJeRFqHk2ewxsMbDEk0owffqyCRl1o5glGtOeHrXdeqv8AbsT+xzGLQ9Logyxqtj1/kue568IO2/hNLr+Es1h5LPW8H3qJAn9Gt6+7+CiE4tpzyZ/93a3I2O7uJBErdHR86KyaKqGWU/VrXJQ89rMv1Y1lW85Otd3yore7wgpfawth5WQuDU9OJbG9kuefbUdxFkU/kNZ24aQ598OBvhwN8LiSulWSZ218Jougm5SKWhC6PHJWbVZUy6qXulrcqfmT30Jf/K9fSo+o1vZ/4Ef1eNd+gfoqkXS5TplUpcVqp+VY/wAlrX7WP/Vpc807ilaXbK1EZcMu4daOumsqn+lartUXVMQwGIYDEMBccc1Qhrb+E5r0WUIwDbp9Z/5/kuaVkEpGks+oKTcjQUnpKgiXS76d57gWUXmP1enuGE3IRRU75fUFL7cCl9Oamar+pbafcWyn6a5da/ax+o0qWhhRMtOR8pRJlZXxOs7OUhib5UFL5MN8iTuzIsbb+E0MahaazTDIx3DhVt0+txn8E7yKIprUxDAYiPFIlhQO0kkbu18VPFrekf5Tn9Xtr5zw0qPKIPKIKJlpyGNQhbYX9VcmtftZHs557vkSto+y/idXDZF0ngY0FhY8oxDAXCxapQ1ufC6XorUkbbj710VrcjL0Us16bW9f4XcPIkk2PO//AMx1Vkqtbt1nWXr4v9Xt1VNGazEcMxHDMRwzEcMxHCszHUC1xxaNJ67Kv0rPXQbyOXjxl48ZePGXjxarts2e5ePGXjxl48ZePGXjwpORqVJC9G6ZXTpV6vaj9o3istHjLR4y0eMtHjLR4y0eMswE9Isl4iAkWaMRlmAyzAXg9bOWloSSbRfLMBlmAyzAXeo0doISjEqGWYDLMBlmAvFy3cnjZNeLXZXaxclpLx9aZZgMswGWYDLMBlmAfvGxrpyzAZZgMtHiXOVSUipxotH5aPGWjxlo8SqSSMj/AOHr/8QAKBEAAgEDAgYCAgMAAAAAAAAAAAECERIxEBMDBCEiUWAgMkFQcICQ/9oACAEDAQE/Af7McfmLO2JdKWWJCQkJCQkOPob7nUSEhISEhISKehSwxISEhISEhISEh59BlhiQkJCG6M4bqqsTXkSEiWX6DLAkJaKNcD6Mu7aHAhdISEif2foLwJCQ6aPqU6VOVn1tEhIn9n6EkJGz4I8v5Hy1XkXL9louTebhISJ/Z+hJCQkJCQkJCRhV9DixISEhISEtOZ5hNWR9Fufkvl5NyXk3Z+Tdn5G28/wNUqVKoqXIuRctLkXoviXxL0bkS5UqbkRTTNyJuRK16m5E3Im5EvizciKSeC+JuR/X0KD0/Hwi6MlnRQbNuQ1SOl3bTThLrXWT7UvhDSMrdIqr/YvRY0TQ3pLOijJ4LZDTUevw4T6aywtIujNyPgvTwvhws/sKD0WNaEY+SWSh1Op1tKMt7CjOH0ZRlGWXQHFooyjIIozhooxV/wAb/wD/xAAxEQACAQIDBQYFBQEAAAAAAAABAgADERASEwQFIDFgITIzQVFxFCIwUFIjcICQoeH/2gAIAQIBAT8B/ifaZTMp9Jlb0hHQuw7BrDUqcolCmndXifZ6VTvLN4buFEalPl0HTTIgUeXGTaVvnUqfPoKl314ybR3jvKnePQNHxF98XqJT7XNom00qhsrAzaK9SltLmmbds2LazVo6lWNtNP8AIR3jvKnePQNHxF98doqtVqFnlHZnqi9P/srqVqFSbw1v0BSHrNjpZ3ueQjvGaP3j0DR8VffHavhqzsyGx/wwEg3Edy7ZmhU5c02Otl+SM0doefQNHxF98CAwsZX3Mt702tF3VY/O0qbvGa4M+HAp6d58Nl84zR36CBt2xGDKGEJtHeO8d4zR3jvGboPd+8FVdKpGqX7RHeO8Zozx3jNFHmehAxXkZr1Pyms/rNRvWFj+wxYDnNRZqLNRZnEziZhM4mYTMMLy/FaWljLHCxmUzKZYzKYQZYzKfth7BjpmaZj88ByPAIfoNiOfAcCL4H7aaRmm2ANpU54DkcLiHA/QbEYEXmUy3A3L7YeUsZYyxgQmOO2Wg5HgAh4vPBsb2MvicGMv/Th//8QASxAAAQIDAgYNCQYFAgcAAAAAAQIDAAQREjQgITGTo+EQEyIyNUFRYXBxcpGSBRQjMEKBobHBQFJgYnOCJFNjouIzQ4OQoLCywtH/2gAIAQEABj8C/wCmNyGN6e6N6e6N6rujenujenujenujIeguu9RymMYKjzxibSPd6vGhJ90YgUnmiu+RyjoGqreJ+P2Gqd4roFRynGfsK+UYx0CAcsU+w0gjk6A2+0Psbo/MegNrtept2TYPHxeqe7XQG11+pIUARbOIwS1VlX5cndFpdlTeS0n1D3a6A2uvCqlggfnxRvUH98emaUjnOSP+Idj94g7U0pdMtIuzndF2c7sF7tdAbXXgomHE1eXjFfZGyUqAKTxGFty+9t4xyHY/eIbSRu1bpWxtST6R3F1DjwXu10BtdeAYaUnIUimx/BKQHK+3xiFtzktZepuFDITClKNVKdUSdhpB3ocCle7YJJoBC3vZyJHNgvdroDa68ES8yfRjer5ICkKCknjGwW3UBSDxGFs1qm2Sk82A620aKI7+bCe7XQG114FAKkwll9FXDulKGUGErl55aEVxps5cFt5GVDqffCVpNUqFRsbckejd+BwX+10BtdeAh1FLSDXHAClbU791X/3ZJcXuuJAymFvO4iXDQcgjKI/eIVLqONvGnqjLC2lEY/hCkK3yTQ4D/a6A2+1hejdcR2VUiipl4jtn1j3bPQGk8h+xrVymvQIhXN9hdXyDoF2o8eT7CJdJ3uNXX0DWXfFG5UD1etq4tKeuCiX8Z6CcTiu+N/8ACMo7oyp8Mez4Y9nwx7Phj2fDGVPhjfJ8Mf6lPcIxvL74x/8ALJKZZuoGVRxAR6SeSlXIluv1jhDQ/wCUcIaH/KOEND/lHCGh/wAo4Q0OuOENDribkfOrPm4rbsZfdWOENDrjhDQ644Q0OuOENDrh8+cbUGiBvLVfjHCGh1xwhodccIaHXHCGh1xwhodceim0LP5k2Yq+ybH304xsKe862uyqzZsV+sX/AEOuL/odcX/Q64v+h1xf9Dri/wCh1xf9Drh2Z88t7X7O10r8YamfPLG2eztdafGL/odcX/Q64cmfPLdim52ulfjCZdKrPGVUrQRf9Dri/wCh1xf9DrhLvne2FSrITYp9YB8/0WuL/otcX/Ra4v8AotcNt7dtttNre0gNsoK1nIBFX30NcwFoxf8AQ64v+h1xf9Dri/6HXF/0OuL/AKHXEtIec124Vt2MnurF/wBDri/6HXF/0OuPN9t23chVbNIEwqY2kKO5FitR3xf9Dri/6HXHCGh1w9LJc2wNmlqlPwu20jfrNkQ3LtDEnKeU8vqPK1eT6jAX1ROdpOGQoAg8RhL7ApLu8X3TEyP6n09RNe75iJTqPz2X+tPzhc0obp40HZGAmXSdwwPiYT1YEv8ApfWE4v4hYqtX09R5P5kj64AZQN04EAQ20gUQgWRsvTCsjaawtxeNSjU/heTB5SfgcAvMy5fVWlBxc8bmWZ8Ji5I8Co3co0O8Rjk2/EYnJkosFxutkHqwCOaJ0cik+omkUxhNodYiYP8AV+mAhsMlxxYrloIurXeYurXiMXVvxGFyypdCQumMGJTqPz2VNOpC21ZQYCUgBIyAbLr6962msLdWarWbRhHVgeTE8SrI/u9T5N6k/M4HnG1p2+zZt8dMBqTSca92rq4vwxLzH8tVT1QhxtQUhYqCMKi0hQ5CIXNySbCk41NDIeqHv0vqMHyh1p+uzLpl7NFgk2k1jEtGbhpBY21tSqH0dMXXsvdg/KHDyun5DAAeaQ4B94Vi5seARc2PAIubHgETC2pZpCxZxpTzxKdX1w2m07xxe6Ow12RgeSO0P/LBWylxxllO9s4rXPGKcf8AGYvr/ji+O98SS33VOKCsqvUTRcxFKrIHMPwzZZcIb+4sVEbthhXeIxyjXiMXNs81TDTxQUFaQqycowJ1kZEhaf7sGf8A2/XZxgGMSR3YEws5EtqPwhf6p+QwGvQlxTlaY6CLknxxjkh7nNUXLSaodlvNbFv2rdYlOr67NSQBz4DzPt0tI69hrsjA8lE8RB/uwaOISscihWLlL5sRcpfNiLlL5sRIpabSgWciRTlwLNRXkwG5xI3Lu5V1j8MSXa+kZBG9T3RvU90b0d2AVKNAMZiae/mBavjg+UP2/M+o82B9K/xflhX6p+QwLDzaXEcihFyZ7oxSbHgi5seARMqRLtJUAKEIA44k+z9dltA9tzH3Q0VGrje4V7sB0AUQ56Qe+GewPlgShGWwfnDboO7yLHIfUSXYH/tgOOlW4t7WrqyYEw1Td0tJ6x+GJRbq0oQCaqUaAYov8rnkxf5XOpi/yudTF/lc6mL/ACudTF+ls6IqZxs9jdQqWlElDKt8s5VQ4t91tobWQCtVOOL/ACudTF/lc6mL/K51MX6VzqY8pF2ZaQlR3JWqlrGYv0rnUxfpXOpi/SudTF+lc6mL9K51MVM6x+1dflBTJoLq/vKxJhTz6ypxXHAQ7MstrtnEtYBi/S2dTF+ls6mL9LZ1MX6WzqYv0tnUxfpbOpi/S2dTE0hE2wpZTiCXASccSqHJthCwMaVOAEY4v0tnRF+ls6Il0szDThC60QsHih5l91LbbgqCs0FRF+ls6Iv0tnRF+ls6IYeZmWXHEGyQhYJoYbBnZaoSP90RfpbOiL9LZ0RfpbOiJQsPNu0Cq2FV5I21k9pJyKgbaSwvkVk74vstnBF+ls6Iv0tnRF+ls6Iv0tnRF+ls6IkXkzDRaSndLChQZeOL9LZ0RfpbOpi/S2dTE2tCgpCnCQRxwwp6aZQ7ZooLWAaxfpbOpi/S2dTF+lc6mJhLLiXGrVUqQain/Y9v/8QALRABAAIAAwUJAAMBAQEAAAAAAQARITFRIEFhwfAQMHBxgZGhsdFggPFAkKD/2gAIAQEAAT8h/wDmME5CwT8pbls61LWpmo/KKMx8ChDnLygvnJ8p8FRgVlLdZbqy3VlurLdWW6st1ZbrEvPGfI8J6kJ8oP8AkvPwGBi1+LSBRRgHf1eDlK8tLg6eAtIrB97/AIAlRrB9rwE4uKgUBkYd+ECYVsnCcUVeAdX6L78IECE4MfZ4Bm/LdygIEorm89kIECBAgrzHgGPY9y21mhY5TFkfN1cJUuzRsL8s+wIECBAlQ15jwJk4x70ffGWQ4YhejtDF65TP6cu3yGXhRyhDE5UCBKnz3gRJNg/Gq49uGBRCxlbgUi2NVnY6t14zCy9+d3oUdmUq/B6rl6wIECVPnvAdfjTOwqmldhyr2aXwDjMx90K4jh5Rd7gZq12FX62d5ir67ATCtXcR3XbFbjl++sCBAlT5LwIV6hxryvDjMrpC2PbekEzbUztWfHYRTknVnBAgQJU+S8B9BIRQGawYbdS4F4ZQYkLujRxr42b7rBNGNntKlzJqPZvRFter75+8CBAlT5zwD+B2AedAGyBG3y0PlvQRLMTsAk8Z9KKoYldKif6kdARjxtg1/j9zgveVUhwdW5ht1ABAlT5nwDdvg+9mmaZWmiRwsEwMa73fKsICSrDQgkCBAgS69F+AfAEdkIECBAgQIECBAgQJgScRP5eAmuTi8+0IECBAgQIECBAgQIEx7pUPNwPAUGXDF59OwIECBAgQIECBAgQIECBaQrT4engKNNwALfJzhVk8UCBAgQIECBAgQIEogeOoGI25lXsRKVbXwHRWKPCftNNQ+YgX54F+Kcb2pxfanH9qcf2p/kp/mJya/Kbh/CkRtK6v/mTvCt3q2FXehJ96baImaO70M3u+RnrsDM2DuRet8QBfBptCMzKV04/MzAi6imXr2DU2vlY3dNe4Xd3dXdch4oGdtZuuS8UTOmnaqubcm9Gs7Ss1RyZb62N3VnT+B1u7TXwXsdmfG2GXjWrMjb7thux6A+j5293VVU8pdb/mZa7CrvNkLuq2W5kMnN+TfewqjxYNc0Xhbvw9P4uOFjDitQngfE3y8+4UWFX7FGx8r9TpWjthUakLGXF1VctPyY7uoXuHnwMupau0rR1GYVd5ejFv22MYCk+8/FT4jYNMz/WYaUW93o4HcVDoPfYrefbLOV9jDgduazK6u494hFu2q/xfK9PXDHybAxKcVgd6t37KWB0v5w3nTcZZCnGRzGPAuUFZZrAYjP02OJyJxv8ASe4cFl8PE5QzfHkbGbtTol1nvjbhCN52Ac9jrNUpHlOlau0AYVkmHBWgUB25uw8+hLfApxW47Gp+tizS+5CcXXYCzLmS9DYzHH0WT3+u8f4Y4IoIG/e+Lg5mZcm0nbdURose7He6HhPn9gzI8DtlZF4zAzNx5CH+ApVLYu4V2iwcuahm8bCMivAdPfY++OaRKCiYd8+Z+22Tj8ULDrTsV9PhsHptzZoGJV4Vb2+B0ElkPqJnMuTBNBLoLe4MVR0mAfvr/GAoAtlz9b+C3l6QUOJAn3N7HlA2AtF0ZJ2b9MntQFOUHI+vIGxmT4P27VfhmpcyI+UV2/sOBsrK00OCqzfWf6v87dB2kNNypHKuE+Z+3bRkN6rYqQv2jifnrFIJSbp1/Q2ByY5suE/SPmdYcp1ByilgPRulKz1GLrTsCrAS22OxlJP03ufX8YpjF4/tE2LeZP8ACT/CRKwXhsDkDsdxAFKDzzLsZkCBzDuAo3P4A4vKCn12MVZ+Yg7A/ZIMAbnWC9iDBvqblr+3ahmX5gT+RszROd5H2rY/2KK+bnXdGw1FQxINNU4dz/e465psH44ZXhhPg47FQWHz4/PX+MIk+zIM1nRnOdDc50NznQXOdBc5mPprzivgmy+JgCOwJaVuJW9MYrTDGdZc51lznWXOdNc4ATNCRmlzprnOiuc6K5zornOiucULBoc6bhDTo9M34j7FxX0aEtZ70q3LOruc6u5zqbnOpuc6m5zqbnOtucIPq0im4YzaeYQzFnS/OdL84jLqUhbSC4qVDjOo/E6X5zpfnOl+cSHdKOAO5PmFtgJwfOdL850vznS/OOxiM67l1AObwyRowY3/ABv0DnL0esfOdL850vznS/OdL850vzg58iLjcm+db851tznU3OP6jOwXmMI3xXUwul35zq7nOruc6q5yxdYBFjmaXXp3j/Sh7l8Fn+lD4LP9KHvHwKfBZ8FnwafBZ718DnuHwWf+L//aAAwDAQACAAMAAAAQAAAAAAAEhBALTAiHACgGgAabEjDRJFhEiGRCPRCAMbxDaAL4KgREkDkkSTNkRJRQCADCAAAAAAAAAAAAACBBAGHAXDJDlkiASbFmiBZIBFgaDImQS4CNLBTVDJhqoQLuiDnmGDlgRBlkCQAFAAAAAAAAAAACAhBEjLDjQBjkiAGSBiAYRBFlohLuIbwrFLFCCAQIEwRJaCXrCSvmGHBAlBIACmDIAAAAAAAAAACBAAjTBTEgDJLZDkBHkAbbaL6IhWCpiBLQiX9jNzBvRiqvHkYABanmmnZAhRYCACDAAAAAAAAACRABbChGDICBDRHAGDFGGhgFkQfAJjEWDI0PCCA6E6AqrbUoJrSYZMniizJQJFECQChAAAAAAAAGAAFCRDKYKEglGlCgWhkhHk5EBonInEOC3pZx6xxi4ZDoOjL/AEk/km7Iwgg5EQYQAI0wAAAAAAAiQAwxARhGhICAgIxIuAak3UkSgRKEj/ohuWwwSzj3atlAq2VBBbN5km7Cym7wJUUQgC4QAAAAABAAEwmgoMhImggC4Z8G3JFYZQZ0ndkHoh+WQwXsspLiH03RYEK6MSJQEm0k2g0yCRZAh0gAAAAAiQA4hAmiIiGGIGmJZGmQ5gyg2gAsC4ohuiIrGalZDzZ+RGnlVYFwmSpRGijBxsxUQSSgC4QAAABgACwiBhEkAhkmgABegGo/EXUEyJUB1DvSjIY2gSrTQxKKiIeQCfLUmysfCsgYgzyIRQAgkwAAAAQA4hAiiIIoI8gHhMQRqAi2g5JKwIUjsSc0Iy43pZLkOwHVQ2g5kwJUEziQI3kUhzUQWQkAKAAAoQEgiBhB0Sm0ZZwIsixG2AYI4kG3zQ3mwAiWPZwlYQHiV4mILZNbAVrSCcsYDyhojyKRYAIxwABgAogACiCZxQawwcgMGSkYhWEWgNpZAQYQXohXoRakMsJqGB4ukyt7AckYMecBxgUkxBUVAhkwAAQBgkAoo8Sy1RU1WHkn5MyjwkQXjhZZNK3ogXoRe1DjC0Y2iG02N7o8PdheRuYD6Im8wAaQkAqAqQEgiElByRQ8w5TxwZgQJWDRIgTxoCJZYEghcaE2QcZgAslVwhF7G8pzKj3IW8A2kRr6IQYACoQgACgACgUV1Va+i8SZ6M2IUoZYED4yZIYymhYExIQDggQyRCkg54k8h6jpRjeUseEiWgxBVRAo11gAolAoqfQwywSBj0QRjUI8DyLVCWSrRGWw7iyzBAxwjB2QHC4rbmHpDh3uI0MLTHyIn/1AVAhF1AAggAgg4aa50UCO48SITGYhi1CgDwAAMKAARQgLwFQABQAAGgFIAZixajmcsDT8A9hIgwAaQlAkQFggFhR6aRU1q4DE70J0Ayx8M6AKwNCBawPJXgCALCQIgEEsQBAE4l4mM0TD8cjH7kQr6KYSkAiQFgqAlV4xUAaJ0oi03SjB2MBBrTyAwwwDDfeewMwlKwggQglCibyUKt8T/kM5DseFiVt6KQaAAwAAgqAgQw1wKAUzq5ac49KfELwUhmqCWF1Ed4gROQhzYwUZwwSYIzITrxMApQ0PaQAqVkwIQYACwAAggKgQRwqpKQfLlbQxUgwKIxSyJAAaAwQCwqAYQCwwQQgZURRFUFNE/qD3frAf6PwagwQVQAKwAAgAKiVVw6lqQcf1/R0AlxgA1aalBgQq6aqAAKQRAwwQQAFQQQAV6gBglP6fvAVfPyahxRVQAqwAAgAKqfVw6lqwQf06XSKg3kaSaQlFABqa4gBAowwQQwQQAFAQaae4lVD2I1QE6e/O64l1lVRAqwAAgAKqfVyl0qwQdQofaP6/gaaaRgUBFgYwAFAgwwwQxTjAAAQQaKwveP6Q1QAfalI7gv3lVVQqwAAgAqq/V6lwq/QQwgPaP61g6afVgQAlgQwAFRgw4wQ6wAKAKQQQAwqav7QwgA/awA/gP/1FVQqwAAgAqq/Valwq/wAEEoBWhOpYGmGBYEAJYENQANUOMMMOsAAACKkEAP6mjZUMIgPX4AP4D/8AUVVCrAACACij9difCj/BdiCdiDCehhBCeBACeBDcADdDDDDDjAAACChBAB+jgedDCgDd+AD+A/8A3HXQo//EACYRAQACAgEEAgIDAQEAAAAAAAEAERAgMCExQGFBUVCRcYGhseH/2gAIAQMBAT8Q4TyzapUrFaV+Ad3w62rzXzTw6lSpWa2r8AR8yvxLgj5dhLPuWSzhrhrmfwlYZfP/AMi62dv/AL5WWa1mpW9eM4PEMkMdusSr+eD/APOsrFStalYrZ5XzzQn+bi//AADSNalSvNcHiGxD+p0/IxErGn037yB/drUryHwThOHu6ekDYMegfudeexkP9DmpUrNeW7vOaGSdzP29moNdSJVsWD4MIT+e2QP7GVKlSpXgPE+OZNTL2x3xv3S16p1Qp/UHqvzdwyDqPX/seuuDq/kfEeBy+SQ2IcWAANMviLbetcTu8j45DJqXZ3AAAC2JFu+7mta5nV4HwjYhCEIaCnaB/KH3p709n9z2/wBzuq8VtXjuXxjYhk1N63rZ0Y6PC+MYslJSUxBq57J7offBHtE2lntnununRu57IJQ9J7IlQz2z3QAp2iHzPdPbDsGeyP0ok0s9kOpZHV1eN2fCtLTuwd2ud/AVhPRHqfvBTDf6MoE073+HFy8Uxoxj4Ls7PCSpTganfjuYEdSA9iod538EXh1D7aE1+o99EdyXiFso6OiCrh4GOXhdnkNxMPWUwNpTKZb6j3cBt0lvqFe0/vEX956J1dvUnol+qd42dp6oUPsnQknqnqiW9Phnol6ifESaqANhLsvdjHR2fFMkMEMENiHiMYxjHZ1Y+KYIQyQhCENCGDJqbuWMYx2Y7PkGCEIQhg3Mmpq4cOjHZjh8L44jJCEIaHO7vGx80hDBCEMmDQ4Did2MYx53nIQhCEIZMGh4Tq6sd3geUwZIQwZMGhyvA4dWO7wPOZIQwZMGhyujHLh0Yx3c/wD/xAAqEQEAAQMDAgUFAAMAAAAAAAABABARIDAxYSFAQVGRobFQcYHB4dHw8f/aAAgBAgEBPxDIzKkOxvg6D2j9NvV1L6xrmBq21HJq9w9yadtFzvR7c0jUOwaidicbOd6R856RDcwcL/Qjs7aB/gJ5/wAh9iPxLEtLS0sQyxP4/c/MmeX87x0TtLaIK2IW0gGYRbtoJEs2xvhet+xNE1raTUXLk+cRHalhUOg+X57sjmaJp20We2fNTLEcoS9GeQl4qXqf6mzLxARS+x4f5jNvUKh7t+aOlfuTE1rS0tVw9u+Sr7db+nH4l3Avlf1W8pf9BsvnH5Ivtb9+0+7x+fCpq/3HtDQIwwNIwIa7PavmigXYmLedy/IW6l4CSyRIl13gh4G56QLn49Suu6+hFDEhq2xcGKycPmjgrj0YhWTyevv/ANnXrx5B+/5HqzHwtt7xZV3W97RuXNvH9nT60Hr2ZpsMShgQoYENZiIHhNhBB9ZYZgYX22F+zMyMNEyNVwaMBLa2z4fZ/TAFy5mHGqweyKGqZkKmJDVYxpv0fZj5r1Yru/WK7qJ3Yt95tV7kxaFCpgQhCHYNGjGMYxjGON9MwKFDMjCppEMDHpynJOSckR3Zzy8XvOWc85Je+0RLIpFjLMSXRVLiiI2l7wnBOCJbk4ILqwbracFDsiMMzIxMFcYt27AVsUeGC1lPhYKzN1LYW63oulqjqcNtLS1FYv2xmQoQoQhChQolyzAvScU2ju5Oq+nxqBFrRDsU3aG6FNzRhYZzRZZXA5DI7EhCEIUIUIYb04JwTgjG0bZLvKBlZlmWYu7N2HjS8XJYkuS5G9gHZlyXIyxLktWtAMUS02dEoYmqQhChgabGMYxoxjGMaOLpGgUKmLiYEMTMq1YxjGNGMY0e7KmLQoQwMjWYxoxjGMaOTomJQ1CNChDMhCEM2rVjGjGNGNGMdMoYlDUI0KGRQhCEIVKs8KNWMYxjGjGMYxrfQNM0iNChoEIQhCpVq1YxjGMaMYxoxxcTM1iNChQyIQhCEKGDgxjGMYxoxjGrHBhgZmsRoUKGRCEIQhQwasYxjGMY0YxjVjgwwMzWIz//xAAqEAEAAgICAQIFBQEBAQAAAAABABARMSAhQTBhUXGBkaFAscHw8dFQ4f/aAAgBAQABPxD9AHMoLN8DgHA4higsKxYcSjug4hxO5iY5pmYmJi8RMcEmLS0tOCUlpSRpLTglP/jHMOQYsM8CgoOBAoM2FYsM0FhwDgHDExMcsTExMck4YrFYj1SRI00lpiJTeKSJSW8kx/5ZZZzCgoOIUFhQcQ4lBYccXiYmJiY9JKxMcMUlJeIkSJSWmIlJxYlJaWlJxf8Axgo4FhxCg4BiBWLCgvFBQXiBAsLxMXiY4YiYrExMTExMTExWJiYrExeJiJEiViYiRKxaRKSngnoNPB4P6sOQcgsLCgoLxAxYWFYvFBWLxQUF4mLCYmJiYmPWxMVi8TFPDF4iRKxExSRKSkzSZjE4JaZtMcEt/VByCwss5nIOBQXiiisTFBA4BQTExMTF4mLxMTFMxMTExxxWJi8RJikvFMSJxSJSUlJbaWnNLT9cFhwNWHohZRwCsWFBWLDEC8WExQVjniYmJiYmJiYvExMTFYmKxMViJMTESktpMUlJEpKSktLbSk9BMfpw4nMsLxiigoLxQWECgvFBMQMVigoJisQIF45YmOOJiYmKxmYmOOJiYvExSTFJSRKTFJSUkSkpKSJSWmLaeCW/pg5BZwOZQZoLxRWOAcMViwmLxQViYmJjjiYvExMehiYiXiYmKxEmLSkiZtIkSkpKS0pKSkiUlJ6Tafqg5lhxLLCsUHAKCgrFhArFhArExwxmYn4NDMEyOezgbKfkp/tv+T/Sf8n+m/5P9N/yO0PzUewme7mlHzMTExMTFpMTExMTF4iTESYvExEmKSkiYiUlJEpKSkpInBLSng/pzicDgUFBYUUUFBQWECgoIF4oJiBisQIFBwxOgL+D8Hn9oYRXwB9mP5gmr9x+0DQHyMTB5fef6E/0J/oT/Yn+xP8AYmTy+8DUfMZgb3n9XUDV18Qfdn+I86B4PweP2mJiYmJiYmJiJiYmJik4JWIkSJSUkSJSUkSk4JSRMRLS0pODb+iDkWcCgoLCigoKDNBWJiBMTGKCF4oIF4oIFhMTEZM4k/Y/k+3zgEADABgD4eukoCjCJkT3gqRlT97+R7fLmlYmLxEiTF4pIkSYpMRIkSkpIlPFIlPJ5P6kOBzCwshRQQsKCBYWFBMTFYsIFhYQ+jaF2vY/GD1wzQfatS7z2fxmJxxMTExMTExMViJEmKxWIkSJSRIkSkpIltJSRKTFJbScG39AeicCggWFhQWUFBQQLCBAmKCBWJisQLxAgTECMfsB9XEHqAg+R16wZsMGDIqPZ6/mMltV9HExMTExMTExWIkSsTFYiRIlJSRIlJEiRKSkiRKSkpInBLaeDb+kDgWFBAsLCg4ECgoIFBQQLCBWLCYvFBAmJieU8/tIuXPx9UM8ADhH4Txd/KTExWJjgkSYmJiYpIlJMUlJEiUkSJEpKSJGkpKSMS2mnm+scTgHohYUHAIUUEKCggUFBAvEC8WECsVgX9cw16DSINeQ2eGT4cAzxAOiYaf3ZisTExMViYmJiYmImJiYmIkSJSTESktIkSJSUlNJSYjEpKS0p4Nv6I5hRDiFBCwogUFECggViwrExeOITF4mYfeho9AAxoAeCPTPLhumR91r6iZagdlNCuj9z3gZ5AAdGYjxMRJiYmLxErFYrESJSUlJSRIkSJSUkTkxODweb6hxOBYUcAoKDgFBYUECgoIUFhYQKxQUGKCz9lDRwBUAVXAG1+EFjGTNT5L9kzA/w2fyB+ZnYTgyU9jlfeLNKWP7dsRuZkY3Q9z/AOKf9gtiHxH/AGDHHwsDpBAxMTExMTExMXiYmIkxMTFJSRIkTNJEiUkSJmJEpImYkSkpKYx4tPB/RnpFBRwKCgoIFBA4BAoJiBAoJiBWKCBWJisUPsIaLXHbDatwM5ewPCMK77x8c0KIcOB8EemDdhXYkPwMI48Z+lA60fuw+OD3nYYn9BiYPhMJ1iq7D9zIPm+ExgWB0hkYmJiY4JWOGJiJMTExMTESJEtIkSmJEiRLSJGkpjGmng8G30jicCyjkUQoKCgsIECwhAoIFhAoJiggViwmIEP2kNF9sHxftGUF20yOKRAuOkPY9GWN+PhFcgyT47DKPllusYM5i4IfyslfmtZSHx+N9xw+S0mwT2ADKvyJixJ/Yhe178AB0giYmJjhiYmPaYmJiYvESJEiUkSJEpIkSJSUkSJGkicGmMeLTwfUOJ6RRQUUQOAQoIELCBAsLCBQViYgTExWIFYgT8ZDRb8IhxHGIK6zvtrw09dgY3yab2Tqhib2Gn4jsfc7hI+PYGg9js98Z88MnwwfARcvGBj6zEBhE2JhOAZ0hxWJMTHtMTExMXiJMTExSWkTNJSRKSJGJGJSRKSkjTTTTTweDb6BxOBZRRCg4HEIUFlhArGaKCgmKCYgQOBQYoJ18HSeLE8Q/KHAB8V6iQCyGWMYPwMYacKncfCRQ43Liy5OsvTPFkEbXHaPrpIAIB/AyP2aw2EwB1tHy0e/AAdGDOBliYmJiMxwxEpLxWIlJSYiUkSkiUkSJSRpjEjTbGPFp5PoHE9IoooKIFBZAoIcCgoKxAoKCwrFYoKxXRP7ZhqwquztddnydnZsi/8AmB0e90Ps+0FIIZE7GZgsadoV8DwPdwQMNgDAgH44PPlV8z/KTISZ8CPlhl4/cxlOz7n0E/y0KI3sUew9xhn3gOzJ5PZ2ezYHSPP93vgzExeJisRJiJMUlJEiUkSkiWlpEjEiRpIlNNNNPB4P6IsoohRQWFBRCwogUEIFBAsJisUFhQTECBYTKHj9lPbggwBHwwEPhg32HEYKHThn8whGVMq7X5s80nwE1pMHsiIWyEwWGX6wR9P7rhiYmJiYiXiYmIkxEpKSJEpIkYkSJEiRpKSJTGMabYxpt4tvI4nA9A5EIGaDNECyBQUUQLCECgmIFBiBMQKCsZv/ADAEYoqmnuwz6wAAYABDocvyn+gEn+ZiYmJiYmKS8XikiRIlpEiUlMSMSJGJGMYxtIlNMY8mnk8jiWWUUbsoohRRQUUFBQTGKCwxCBwxAsJisUHEs5kJ8jp/JQZ9cAAMABYHuJ/mH8R54mJiYmKxeKSJEtIkSkiUlJiJbGMYxjGNMaYxp4PB9A9AsoohyIQooIQKCECggUEOAXiExYQooKxAiQJiVLmfu+r9z3gZ/QAAAgAdupA66dfSVfd9qxxxMTFYmIkxSUlJEiRKSJEiRIxIkYxjTGMbSNNMYxpt4tu+BxOBRxIQosohRAgUEIUEKCyghwCwxCBMUFBQUEQAonYniERkdBZz8n8kA+2wv23MG+vTADAM3R2+0S/GEU/I2/QjyT0ZAH73u/Q8xACMquVZiYmJiJySmkrFJaRIkbTEYlMYxKYxjGmMeDTwadU75PA4lllFm6OBCiFEOJZAzRCgoLCFBigsLCYoKCgwhpWGCYMfBQ/M/kv/AMQjGf5/84Js92AEwlgUwGYuYD+UlTAfy/5zSfSkCIxeFH2MR217TK/W8TExxxMTFYiTFYtIkSmJEjEtIlJaRpjGMaSNNsdxppp4O6dcD0CzVFEIbo3ZRZCFBDdhDgQgUEKCFYxQQoKxCFBQWFBmwvHDFY44mJjlisRJikpIkSNJEpiRiRjGMaYxpp3GJTTGMadW7jrg+kcDmQhRRDdELNQhRDcN0QoIECiBQUQKLDgUUFhQWFhePVxHikxEiUlJiJEiRMxiWxIlNMYxjGMYxjG2nk8XVu6N8TfIo3ZRqjVEKKOBZCjVBQWFBWIUQIECywoM2FYsLC8ccTHNvETmlJaWkSmMYxjGMS2MY2xpt3TummnfJo3xLN2UUbhRriaoohuFlFlkKCHEs4Y6gUHEKLCwvHDExyxMXiYvExSU0lpGJGmJbGJGMYxjGMY07jGnVMYxp4PJo9AsoohZuiyEN0QhwKIQ4ERgg3z1l8+xl9ouK6A/U79oY1uMLVH1Mzu+fdD69H3WuD+7BBQveB95x6LU7IWfCHzbhjwZzJhCSJGTNPqRATZwMP8AP8TCgu2hz9A0GfDHjku6qlDKnj3LWJpeWnU+w4tYm15aLEdBcbcINLedOpkjN2AnayM9oBk7ThIibrtEkUfAsHWPMzBhiw74ycL/AOOPt9r34Y7tbz9I+y8Zc9/YPK9EQ5dl3zmHJ8lzEZERxgHF+mez7LdS50VBTkGanf5BjefMzL7jKzHfoEAMOs+aVzqyeklHbA1MJ2f2RjGMYxjGPBiRpjGMY6jG2Oox1Trg64O6aPQNczVFFEN0UWQhRCzUIbhXut5ow/LBJB6cLPrF9jBo5umDxhQewr7Y4df7vb0KblTCAuxHpI7FV+J5x9jKfDCfCJB6x9Tn9vQy3/6ZcPeA3xflBWvGrh8Ceyr3w4aTBR6cX2cP3n9B8Dg4RVgB5iRriRnIZzeM2MeUX0G8MF9QhovG1iDOBwfkAV+TC7B14AD69Xi17ccYj7jgfWKBS/ylX7tJGmJwSMYxjbGOoxpjTuNOuTxeBwN8jmUWboso1CHAoKIQmJfEc/40Q1bHifUzM4SowHXkam10Hfbk4ZabwOYXDLjHS9nLEh8bGflRwGEDTadvl9eH+/wMxzOSn5Yf49ARjid9Hj6I+sIPhPyMf78GFGL328CrI9GuvjMphmehaZnePYJ/aP4jLlNDGj124Tybs/sh8iImfqDA/BKBGAA0BbEArF2Do91wfWMSTvyxflnv2/uOAM+WnxMskOGZmZJk+MENvI+kjRaKlwD6s1wfBleHWfj4950T2c36aYxjGNMYwRjGMYxjTbGmNPBp4vA4HIo3ZuiiG6KIboohRCyFkNTYcHjQT5oRQpSZWZE4YJj5/eddbkTfRMRfRT+qZD4DvDpx1h3wTfisDsd5cfW6t99hAAHPXTEMK/Bf8R/evnbDC0MvfXUKIQKBE6YA06Nflj/fg8Fslq9sOp/bv4n9u/if3L+JmJgN43AMnSn19D+IphF85/NyyRFO1vx4Flx2hwHUFSeUZQVHvNU3gxjGczzYDB/2h+MTX/QZkMPn3f3JkvWZCwHwM5YaOTqLPaLnxn5hBtI0xjGMeDGMdRjuO6dxjTbuO47p3TqnduuBrgWbsoohRqyiG4Qs3CFEIUUUapSyOADKxI1HWS7QPyGZhUecpn2Z+IIcl4wf+xJVduz4Dj+IXDQ+wHwdmbcAK6R0kxYAyawp+OH4rG4c9X/tQWLD7xPKvxA/iAOgwfC24BRlxnHRxWoKmA4/ucC56YA+NRSvfPdP3jF84FqjmeSnTnw3wfq8dhIDLg7eBH/YHx1n17ggZCKMI/Dj6RIHR0CT+IcDgV2fZAMVcteveDKZmzn44C7UAZwH2hosRMYAwHSm8dcOrkrB0F2f697Y27icGMYxjbqMYxjHdOqYx3GmnVNuvQLLNUUQs3RZCEN0Q1DgUcCj0APUmYhgjGgZ/Wv4n9a/iAhjyA/twZoVLABlX5BPbDLAd+HgMgbww10AR8PoJbunE95h/ZQHxy/CKp5p9n+OCJ89OT8TOn3J/c/9guNLH/SIWGU/tqKJkXPxgJEPifktc4AwawU/XL6Rv2Y5lYMnutfPNsLoliGAMsD5Gc+7fDHPOAbEKP3mEJYHs2x8HT2fRaGinTArH5MWZ+h8xByWOdK6O9Ae7hg7jGMYxjTuMYxjGNsYxjGMd2xjGnXB5HEs4mqIasohuijUKIUcCEKIbolpzelj0DtDv4wxHEJUqdO47Kz/AEiFAIZGR9CwYt/PXIe/z3lOujI5G5g86SwXA9e3BaNGsqnmvNg2VmTCPXxOVXixYsSAZnCf2SingIi34/s/umWizqgeAOg0B0Qo8XiR6OA4cb9CTJMmTJlzgPYeBMCF1Do1ogrgBHCbv37xA1kKMo3BljbDIMYxkAUfPDhjx4wTSFyznIcQFjHzrQicOPHjw7IQdUE3Ge8Z94ffAMy/Cn7J2feYpx7jP7B6+QgIofDn2Q8sePHz9pUIqYdAcNPPkhhL25MitTe48A6R+JDW1DvaQHTt73JkrmIEwkBLIQ6HYx5UY6pI0x3GMaOo6p1HcdxjGNsbY6jHVOrY8HmWcSjgWUUQso1DcN0Q1CiEKIUQ4hRRqeOJ5o3RRCELLeiBzOGJiY4PBppppptjGMY8WMY7pt8xp3Gm3VsdcHfpFG/RIboo3ZqG4bhZuFnAhqiGoUQssnivhRRuyjXDxDiRhwCO4HoJxTkxtjuMdx3HiY7jHcd0YxjuNO4xp3Gm23i79Io3wIUUahujUIbshCEKIWUUcCFGoUbhuyGobsos1ybLNTzwPUS3g7p3TqmOo0xjGncdxjGO40dRjHcdx3GMabfPJ3xeRvkUUbhujdELNwhZqENQohCiijiUeLNwoohxORujfA16Br1XfBppppjGmMdRjHcYxjGMbdRjHcYx8028ni8jfIoo3DdFlkIbs1DUNQohCjdGuBRuzxZCiyiyijdFHAo4hn1m3ceDTHcafNMaY7jGNGMY2xjHcYx3TbumndPF5G+RRujcKLIUQhvgahqGqIahCG6IbsosshRZRxKKKLLOJ6zbunixjTum3zGMY0dR1HUYxjuMYx1GO4xtjuO6aeLyN8iiiFEKNQohqG6N0Q1DVENQhCyG6IbhRqFG6LKNUaoohRRRqzdmuJ6zbummmOo20x3TGOo6jqMY06juO4xjqMdR1GMdWx3Gmmm3XI3yKKIUQ3RqG6IahuEN0Q1DVENQhCFENwohRqFG6NQ3RRqjVFENUUcTmb9dt3TqmmmncY7jHcdxoxjHgxjuNHUY6jGMdU7jHcaaad265G+RRRCiG7N0ahqG4bhuiGoaohqEIQohCjUKIUUahujdGqNUUeYTxCjiUcTf6J3TqmmmncY7jqMY0YxjG2Mdxj5jGOoxjbGO4000265G+RRRCiG4UWahuG4bohDVEKIQo1CFGoUQoo1DdG6OBRXiGqOJRxN8sTExMTExxd074NNNMdRjGMaMadR3wYxjuMY6pju2MY000265G+RRRCiEKLNQ3DcKIQ1ZRCFGoQo1CiFFGobos3ZqivEOZRxORrk64O6d28XdMdRpjHiY7jbGMdxjq2NMYxjTTTbrkb5FFEKIQohRqG4QshCiiEKNQhZRCijUKLN8SyFG+BqjfE5GuTrg07tp3buO400xjGmNHcdx3HcYxjuNsY0xjGNNNNuuRvkUUQohCiFGobhDVkIUUahCjUIWWUUahRZviWQo4FF+PQNcng0207p3HcY6ppjqOo07jujuO47juMYxjbRpjGMaaabdcjfIoohRCFEKNQ3CGobohqFG7IWQ1ZDdFFFlm+JZCjgUX4PQNcnk6tp3TuMY6pp8x1GNO47j5jHcdx3RjGNtGmMYxpppt1yN8iiiFEIUQo1DcIahujUNQo3ZCFELIUcDxZZviWQo4FF+D0DXJ5Orad07jGOqafMdRjGO47juMdx3HcfMYxjbRpjGMaaabdV//9k=';
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

// ------------------------------------------------------------------ the site's mode and visits
// index.php (the home page) and np7dpanel.php share these. The mode lives
// in sidekick-wishlist/site.json: a wishlist (the default) or released,
// with downloads of the newest release (or one version, pinned). Visits are counted per day in
// sidekick-wishlist/visits.json (a day's visitors only as short hashes of
// IP + browser, salted with the day, so nobody can be traced back). The IP
// addresses themselves (bots too) are kept 30 days in ips.json, for the
// panel's "Who visited" list.

const REPO = 'dankordigital/sidekick';
const VISIT_DAYS = 400;        // days of visits kept

function site_state(): array {
    $state = ['released' => false, 'version' => '', 'changed' => '', 'auto' => true];
    try {
        $raw = @file_get_contents(data_dir() . '/site.json');
        $saved = $raw ? json_decode($raw, true) : null;
        if (is_array($saved)) $state = array_merge($state, array_intersect_key($saved, $state));
    } catch (Throwable $e) {
    }
    $state['auto'] = (bool)$state['auto'];
    $state['released'] = (bool)$state['released'] && preg_match('/^\d+\.\d+\.\d+$/', (string)$state['version']);
    return $state;
}

/** Saves the website's mode. [$auto]: released, it follows the newest
 *  release on GitHub by itself (offered_version), [$version] being the
 *  last one it offered; otherwise it stays on [$version]. */
function save_site_state(bool $released, string $version, bool $auto = true): bool {
    $state = ['released' => $released, 'version' => $version, 'changed' => gmdate('Y-m-d H:i:s'), 'auto' => $auto];
    return file_put_contents(data_dir() . '/site.json', json_encode($state), LOCK_EX) !== false;
}

/** The version the home page offers while released. Following the newest
 *  (auto, the default): the newest release on GitHub, as soon as it has
 *  every download file (a release still being built never gives a broken
 *  link); until then, or when GitHub can't be reached, the last one it
 *  offered. The newest is asked at most every 10 minutes (latest_release). */
function offered_version(array $state, ?array $latest = null): string {
    if (!$state['auto']) return $state['version'];
    try {
        $latest ??= latest_release(false, 4);
    } catch (Throwable $e) {
        return $state['version'];
    }
    $version = (string)($latest['version'] ?? '');
    if ($version === '' || $version === $state['version'] || !release_complete($latest)) return $state['version'];
    // Remember it, so it's what's offered if GitHub is ever out of reach.
    $saved = json_decode((string)@file_get_contents(data_dir() . '/site.json'), true);
    if (is_array($saved)) {
        $saved['version'] = $version;
        @file_put_contents(data_dir() . '/site.json', json_encode($saved), LOCK_EX);
    }
    return $version;
}

/** [$latest] (from latest_release) has every file release_files() links. */
function release_complete(array $latest): bool {
    $have = $latest['assets'] ?? null;
    if (!is_array($have) || !isset($latest['version'])) return false;
    foreach (release_files((string)$latest['version'])['files'] as $url) {
        if (!in_array(basename($url), $have, true)) return false;
    }
    return true;
}

/** The download links for a release, as the Build workflow names them. */
function release_files(string $v): array {
    $base = 'https://github.com/' . REPO . "/releases/download/v$v/";
    return [
        'version' => $v,
        'page' => 'https://github.com/' . REPO . "/releases/tag/v$v",
        'files' => [
            'windows' => $base . "SidekickSetup-$v.exe",
            'macos' => $base . "Sidekick-$v-Apple-silicon.dmg",
            'macosPkg' => $base . "Sidekick-$v-Apple-silicon.pkg",
            'macosIntel' => $base . "Sidekick-$v-Intel.dmg",
            'macosIntelPkg' => $base . "Sidekick-$v-Intel.pkg",
            'android' => $base . "Sidekick-$v.apk",
            'ios' => $base . "Sidekick-$v.ipa",
        ],
    ];
}

/** [status code, body or false] for a GET over HTTPS, with curl or PHP's own. */
function http_get(string $url, array $headers = [], int $timeout = 10): array {
    $headers[] = 'User-Agent: Sidekick-website';
    if (function_exists('curl_init')) {
        $c = curl_init($url);
        curl_setopt_array($c, [CURLOPT_RETURNTRANSFER => true, CURLOPT_HTTPHEADER => $headers, CURLOPT_TIMEOUT => $timeout,
                               CURLOPT_FOLLOWLOCATION => true]);
        $body = curl_exec($c);
        $code = (int)curl_getinfo($c, CURLINFO_HTTP_CODE);
        curl_close($c);
        return [$code, $body];
    }
    if (!ini_get('allow_url_fopen')) return [0, false];
    $ctx = stream_context_create(['http' => ['header' => implode("\r\n", $headers), 'timeout' => $timeout, 'ignore_errors' => true]]);
    $body = @file_get_contents($url, false, $ctx);
    $code = preg_match('/^HTTP\/\S+ (\d+)/', $http_response_header[0] ?? '', $m) ? (int)$m[1] : 0;
    return [$code, $body];
}

/** The newest release on GitHub: ['version' => '2.17.2', 'published' => …,
 *  'url' => …, 'assets' => [file names]], or ['error' => why]. Asked at
 *  most every 10 minutes (GitHub limits how often a server may ask),
 *  unless [$fresh]; [$timeout] seconds at most (the home page waits less). */
function latest_release(bool $fresh = false, int $timeout = 10): array {
    $cache = data_dir() . '/latest-release.json';
    $saved = json_decode((string)@file_get_contents($cache), true);
    if (!$fresh && is_array($saved) && time() - (int)($saved['checked'] ?? 0) < 600) return $saved;
    [$code, $body] = http_get('https://api.github.com/repos/' . REPO . '/releases/latest', ['Accept: application/vnd.github+json'], $timeout);
    $json = is_string($body) ? json_decode($body, true) : null;
    $version = ltrim((string)($json['tag_name'] ?? ''), 'vV');
    if ($code === 200 && preg_match('/^\d+\.\d+\.\d+$/', $version)) {
        $latest = ['version' => $version, 'published' => str_replace(['T', 'Z'], [' ', ''], (string)($json['published_at'] ?? '')),
                   'url' => (string)($json['html_url'] ?? ''), 'checked' => time(),
                   'assets' => array_values(array_map(fn($a) => (string)($a['name'] ?? ''), (array)($json['assets'] ?? [])))];
    } else {
        $why = $body === false ? 'couldn\'t reach GitHub' : ($code === 404 ? 'GitHub has no release yet' : "GitHub answered $code");
        // Keep showing the last good answer, saying it couldn't check again.
        $latest = is_array($saved) && isset($saved['version']) ? $saved + ['error' => $why] : ['error' => $why];
        $latest['checked'] = time();
    }
    @file_put_contents($cache, json_encode($latest), LOCK_EX);
    return $latest;
}

// ------------------------------------------------------------------ the home page's texts
// np7dpanel.php → Edit changes the home page's texts without uploading
// index.html again: the edits live in sidekick-wishlist/edits.json and
// index.php puts them in as it serves the page. index.html itself is never
// changed, so a new upload doesn't lose them. Each edit says which text it
// replaces; if that text isn't on the page any more, the edit does nothing.

/** Every piece of text on [$html] someone reads, as [key => text], in order.
 *  Scripts, styles, comments and icon names aren't text. */
function page_texts(string $html): array {
    $texts = [];
    page_text_walk($html, function (string $text) use (&$texts) {
        $texts[text_key($text)] = $text;
        return null;
    });
    return $texts;
}

/** [$html] with the edits put in. */
function apply_site_edits(string $html, ?array $edits = null): string {
    $edits ??= site_edits();
    if (!$edits) return $html;
    return page_text_walk($html, function (string $text) use ($edits) {
        $edit = $edits[text_key($text)] ?? null;
        return $edit !== null && $edit['from'] === $text ? $edit['to'] : null;
    });
}

/** [$html] for np7dpanel.php's visual editor: every text the Edit tab can
 *  change, with the edits put in, wrapped in
 *  <span class="sk-text" data-sk="key" data-sk-orig="text on the page">.
 *  Texts in <title>, <option> and <textarea> stay as they are (spans can't
 *  go there); the list view still has them. */
function page_editable(string $html, ?array $edits = null): string {
    $edits ??= site_edits();
    $parts = preg_split('/(<!--.*?-->|<script\b.*?<\/script>|<style\b.*?<\/style>)/is', $html, -1, PREG_SPLIT_DELIM_CAPTURE);
    foreach ($parts as $i => $part) {
        if ($i % 2) continue;
        $parts[$i] = preg_replace_callback('/(<[^>]+>)([^<]*)/', function ($m) use ($edits) {
            if (preg_match('/^<\s*(title|option|textarea)\b/i', $m[1])) return $m[0];
            if (preg_match('/class="(?:[^"]*\s)?icon(?:\s[^"]*)?"/', $m[1])) return $m[0];
            $text = preg_replace('/\s+/u', ' ', trim(html_entity_decode($m[2], ENT_QUOTES | ENT_HTML5, 'UTF-8')));
            if (!preg_match('/\p{L}/u', $text)) return $m[0];
            $key = text_key($text);
            $edit = $edits[$key] ?? null;
            $edited = $edit !== null && $edit['from'] === $text;
            preg_match('/^(\s*).*?(\s*)$/s', $m[2], $ws);
            $attr = fn(string $v) => htmlspecialchars($v, ENT_QUOTES | ENT_HTML5, 'UTF-8');
            return $m[1] . $ws[1] . '<span class="sk-text' . ($edited ? ' sk-saved' : '') . '" tabindex="0" data-sk="' . $key
                . '" data-sk-orig="' . $attr($text) . '">' . htmlspecialchars($edited ? $edit['to'] : $text, ENT_NOQUOTES | ENT_HTML5, 'UTF-8')
                . '</span>' . $ws[2];
        }, $part);
    }
    return implode('', $parts);
}

/** The home page in released mode: <html class="released"> and the download
 *  links of [$version] in SIDEKICK_RELEASE (index.php, and the editor's
 *  Released view). */
function mark_released(string $page, string $version): string {
    $release = json_encode(release_files($version), JSON_UNESCAPED_SLASHES | JSON_HEX_TAG);
    $page = preg_replace('/<html lang="en"/', '<html lang="en" class="released"', $page, 1);
    return preg_replace('/<\/head>/', "<script>window.SIDEKICK_RELEASE = $release;</script>\n</head>", $page, 1);
}

/** Calls [$visit] with each text; where it returns a string, that replaces
 *  the text (whitespace around it kept). */
function page_text_walk(string $html, callable $visit): string {
    $parts = preg_split('/(<!--.*?-->|<script\b.*?<\/script>|<style\b.*?<\/style>)/is', $html, -1, PREG_SPLIT_DELIM_CAPTURE);
    foreach ($parts as $i => $part) {
        if ($i % 2) continue;
        $parts[$i] = preg_replace_callback('/(<[^>]+>)([^<]*)/', function ($m) use ($visit) {
            if (preg_match('/class="(?:[^"]*\s)?icon(?:\s[^"]*)?"/', $m[1])) return $m[0];
            $text = preg_replace('/\s+/u', ' ', trim(html_entity_decode($m[2], ENT_QUOTES | ENT_HTML5, 'UTF-8')));
            if (!preg_match('/\p{L}/u', $text)) return $m[0];
            $new = $visit($text);
            if ($new === null) return $m[0];
            preg_match('/^(\s*).*?(\s*)$/s', $m[2], $ws);
            return $m[1] . $ws[1] . htmlspecialchars($new, ENT_NOQUOTES | ENT_HTML5, 'UTF-8') . $ws[2];
        }, $part);
    }
    return implode('', $parts);
}

function text_key(string $text): string {
    return substr(sha1($text), 0, 12);
}

/** The saved edits: [key => ['from' => text on the page, 'to' => new text]]. */
function site_edits(): array {
    try {
        $saved = json_decode((string)@file_get_contents(data_dir() . '/edits.json'), true);
    } catch (Throwable $e) {
        return [];
    }
    return is_array($saved) ? $saved : [];
}

function save_site_edits(array $edits): bool {
    return file_put_contents(data_dir() . '/edits.json', json_encode($edits, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT), LOCK_EX) !== false;
}

/** A network that's a cloud provider, hosting company or scanner, not
 *  somebody's internet at home or on their phone: visits from it are bots,
 *  whatever browser they claim to be. ("6 Collyer Quay" is Tencent Cloud's
 *  address in Singapore.) */
function is_cloud_network(string $network): bool {
    return $network !== '' && (bool)preg_match('/alibaba|aliyun|tencent|collyer quay|amazon|aws|google cloud|google llc|microsoft|azure|'
        . 'digitalocean|linode|akamai|ovh|hetzner|vultr|choopa|oracle|censys|shodan|leaseweb|m247|datacamp|cdn77|contabo|'
        . 'scaleway|hostinger|ionos|cloudflare|huawei|byteplus|bytedance|zenlayer|psychz|quadranet|colocrossing|'
        . 'hosting|datacenter|data center|server|cloud/i', $network);
}

function is_bot(string $ua): bool {
    return $ua === '' || (bool)preg_match('/bot|crawl|spider|slurp|preview|fetch|monitor|curl|wget|python|scan|headless|lighthouse/i', $ua);
}

/** Counts one visit to the home page (not bots, not the owner's panel). */
function record_visit(): void {
    $ua = (string)($_SERVER['HTTP_USER_AGENT'] ?? '');
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET') return;
    record_ip($ua);
    if (is_bot($ua)) return;
    $day = gmdate('Y-m-d');
    $who = substr(hash('sha256', $day . '|' . ($_SERVER['REMOTE_ADDR'] ?? '') . '|' . $ua), 0, 12);
    $from = parse_url((string)($_SERVER['HTTP_REFERER'] ?? ''), PHP_URL_HOST) ?: '';
    $own = $from !== '' && $from === ($_SERVER['HTTP_HOST'] ?? '');
    $f = @fopen(data_dir() . '/visits.json', 'c+');
    if (!$f) return;
    flock($f, LOCK_EX);
    $data = json_decode(stream_get_contents($f) ?: '', true);
    if (!is_array($data)) $data = ['days' => [], 'from' => []];
    $d = $data['days'][$day] ?? ['v' => 0, 'u' => []];
    $d['v']++;
    if (!in_array($who, $d['u'], true)) $d['u'][] = $who;
    $data['days'][$day] = $d;
    if ($from !== '' && !$own) {
        $from = preg_replace('/^www\./', '', strtolower($from));
        $data['from'][$from] = ($data['from'][$from] ?? 0) + 1;
        arsort($data['from']);
        $data['from'] = array_slice($data['from'], 0, 50, true);
    }
    ksort($data['days']);
    $data['days'] = array_slice($data['days'], -VISIT_DAYS, null, true);
    ftruncate($f, 0);
    rewind($f);
    fwrite($f, json_encode($data));
    fflush($f);
    flock($f, LOCK_UN);
    fclose($f);
}

const IP_DAYS = 30;            // days an IP address is kept
const IP_MAX = 3000;           // addresses kept at most

/** Notes the visitor's IP address (bots too, marked) in
 *  sidekick-wishlist/ips.json for np7dpanel.php → Visits: when it came
 *  first and last, how often, its browser. Kept IP_DAYS days. */
function record_ip(string $ua): void {
    $ip = (string)($_SERVER['REMOTE_ADDR'] ?? '');
    if (!filter_var($ip, FILTER_VALIDATE_IP)) return;
    $f = @fopen(data_dir() . '/ips.json', 'c+');
    if (!$f) return;
    flock($f, LOCK_EX);
    $ips = json_decode(stream_get_contents($f) ?: '', true);
    if (!is_array($ips)) $ips = [];
    $now = gmdate('Y-m-d H:i:s');
    $row = $ips[$ip] ?? ['first' => $now, 'n' => 0];
    $row['last'] = $now;
    $row['n']++;
    // A bot only while every visit looked like one; the browser a person used.
    $bot = is_bot($ua);
    if (!$bot || ($row['bot'] ?? true)) $row['ua'] = substr($ua, 0, 300);
    $row['bot'] = ($row['bot'] ?? true) && $bot;
    unset($ips[$ip]);
    $ips[$ip] = $row;   // newest last
    $cutoff = gmdate('Y-m-d H:i:s', time() - IP_DAYS * 86400);
    $ips = array_slice(array_filter($ips, fn($r) => $r['last'] >= $cutoff), -IP_MAX, null, true);
    ftruncate($f, 0);
    rewind($f);
    fwrite($f, json_encode($ips));
    fflush($f);
    flock($f, LOCK_UN);
    fclose($f);
}

/** The IP addresses of the last IP_DAYS days, newest first:
 *  [ip => ['first', 'last', 'n', 'ua', 'bot']]. */
function visitor_ips(): array {
    try {
        $ips = json_decode((string)@file_get_contents(data_dir() . '/ips.json'), true);
    } catch (Throwable $e) {
        return [];
    }
    if (!is_array($ips)) return [];
    $cutoff = gmdate('Y-m-d H:i:s', time() - IP_DAYS * 86400);
    $ips = array_filter($ips, fn($r) => ($r['last'] ?? '') >= $cutoff);
    uasort($ips, fn($a, $b) => strcmp($b['last'], $a['last']));
    return $ips;
}

/** Where IP addresses are: [ip => ['country', 'code', 'city', 'network']],
 *  from ipwho.is, asked only from the panel and at most [$max] new ones at a
 *  time; answers are kept in sidekick-wishlist/ip-places.json while the
 *  address is. */
function ip_places(array $ips, int $max = 25): array {
    $file = data_dir() . '/ip-places.json';
    $places = json_decode((string)@file_get_contents($file), true);
    if (!is_array($places)) $places = [];
    $asked = 0;
    foreach ($ips as $ip) {
        if (isset($places[$ip]) || $asked >= $max) continue;
        $asked++;
        if (!filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE)) {
            $places[$ip] = ['country' => 'This network', 'code' => '', 'city' => '', 'network' => ''];
            continue;
        }
        [$code, $body] = http_get('https://ipwho.is/' . rawurlencode($ip) . '?fields=success,country,country_code,city,connection', [], 4);
        $j = is_string($body) ? json_decode($body, true) : null;
        if ($code !== 200 || !is_array($j) || empty($j['success'])) continue;   // asked again next time
        $places[$ip] = ['country' => (string)($j['country'] ?? ''), 'code' => (string)($j['country_code'] ?? ''),
                        'city' => (string)($j['city'] ?? ''),
                        'network' => (string)($j['connection']['org'] ?? $j['connection']['isp'] ?? '')];
    }
    $places = array_intersect_key($places, array_flip($ips));
    if ($asked) @file_put_contents($file, json_encode($places), LOCK_EX);
    return $places;
}

/** ['days' => [date => ['v' => visits, 'u' => [visitor hashes]]], 'from' => [site => visits]] */
function visits(): array {
    try {
        $data = json_decode((string)@file_get_contents(data_dir() . '/visits.json'), true);
    } catch (Throwable $e) {
        $data = null;
    }
    return is_array($data) ? $data + ['days' => [], 'from' => []] : ['days' => [], 'from' => []];
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
