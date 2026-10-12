<?php
/*
 * Checks the hosting can run the wishlist (wishlist.php): PHP, a private
 * folder for the list, the mailbox password, and a real test email sent the
 * same way the wishlist sends. Upload next to wishlist.php, open
 * https://getsidekick.app/wishlist-check.php, then delete it. It only ever
 * emails the wishlist's own address (FROM).
 */
define('WISHLIST_LIB', true);
require __DIR__ . '/wishlist.php';
header('Content-Type: text/html; charset=utf-8');

$checks = [];
$checks[] = ['PHP ' . PHP_VERSION, version_compare(PHP_VERSION, '8.0', '>='), 'wishlist.php needs PHP 8.0 or newer (OVHcloud: Web Cloud → Hosting → General information → PHP version).'];
try {
    $dir = data_dir();
    $writes = @file_put_contents("$dir/.check", 'ok') !== false;
    if ($writes) @unlink("$dir/.check");
    $where = str_starts_with($dir, __DIR__) ? 'inside www (protected by .htaccess)' : 'next to www (not reachable from the web)';
} catch (Throwable $e) {
    $writes = false;
    $where = '';
}
$checks[] = ["A private folder for the list $where", $writes, "The hosting doesn't let PHP save files. In FileZilla, www should be 705 or 755."];
$checks[] = ['PHP can open secure connections (openssl)', extension_loaded('openssl'), 'Ask OVHcloud support to enable the openssl PHP extension.'];
$hasPassword = smtp_password() !== null;
$checks[] = ['The mailbox password is set (wishlist-config.php)', $hasPassword, 'Upload wishlist-config.php with the password of ' . FROM . ' (see wishlist-config.example.php).'];

$sent = null;
if (isset($_POST['send'])) {
    $sent = send_mail(FROM, 'Sidekick wishlist: test email',
        "It works! The wishlist on getsidekick.app can send email.\r\n\r\nSent at " . gmdate('Y-m-d H:i:s')
        . " UTC by wishlist-check.php. Delete that file from the hosting now.\r\n", FROM_NAME, FROM);
}
$log = @file_get_contents(data_dir() . '/mail.log') ?: '';
$lastLines = implode("\n", array_slice(explode("\n", trim($log)), -5));
$all = !in_array(false, array_column($checks, 1), true);
?><!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex"><title>Wishlist check</title>
<style>
body{font:16px/1.5 system-ui,sans-serif;max-width:680px;margin:40px auto;padding:0 16px;background:#fbf8ff;color:#1c1b20}
li{margin:10px 0;list-style:none}.ok{color:#146c2e}.bad{color:#b3261e}small{display:block;color:#5d5a66}
button{font:inherit;padding:10px 18px;border-radius:12px;border:0;background:#6750a4;color:#fff;cursor:pointer}
.box{padding:16px;border-radius:16px;background:#ece6f6;margin-top:20px}pre{white-space:pre-wrap;font-size:13px;background:#fff;padding:10px;border-radius:10px}
</style></head><body>
<h1>Sidekick wishlist check</h1>
<ul><?php foreach ($checks as [$what, $ok, $fix]): ?>
<li class="<?= $ok ? 'ok' : 'bad' ?>"><?= $ok ? '✔' : '✘' ?> <?= htmlspecialchars($what) ?><?php if (!$ok): ?><small><?= htmlspecialchars($fix) ?></small><?php endif ?></li>
<?php endforeach ?></ul>
<div class="box">
<?php if ($sent === true): ?>
  <b class="ok">The mail server accepted the test email to <?= htmlspecialchars(FROM) ?>.</b>
  <p>It should arrive within a few minutes (look in spam too). Then the wishlist works: delete this file from the hosting.</p>
<?php elseif ($sent === false): ?>
  <b class="bad">The test email couldn't be sent.</b>
  <p>Why, from the log:</p><pre><?= htmlspecialchars($lastLines) ?></pre>
<?php else: ?>
  <p>Send a test email to <b><?= htmlspecialchars(FROM) ?></b>, the same way the wishlist sends:</p>
<?php endif ?>
  <form method="post"><button name="send" value="1">Send a test email</button></form>
</div>
<?php if ($log !== '' && $sent === null): ?><p>Recent email problems:</p><pre><?= htmlspecialchars($lastLines) ?></pre><?php endif ?>
<p><?= $all ? 'Everything the wishlist needs is here.' : 'Fix the ✘ items above, then reload this page.' ?></p>
</body></html>
