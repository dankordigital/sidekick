<?php
// The home page. Serves index.html as it is, after counting the visit and
// saying whether the site is a wishlist or released (np7dpanel.php →
// Website switches it). Released: <html class="released"> shows the
// downloads instead of the wishlist, and SIDEKICK_RELEASE has the links,
// for the newest release on GitHub unless a version is pinned.
// Texts changed in np7dpanel.php → Edit are put in here (edits.json).
// .htaccess sends "/" and "/index.html" here; without PHP, index.html is
// still the wishlist.

declare(strict_types=1);

define('WISHLIST_LIB', true);
require __DIR__ . '/wishlist.php';

$page = (string)file_get_contents(__DIR__ . '/index.html');
try {
    record_visit();
} catch (Throwable $e) {
}
try {
    $page = apply_site_edits($page);
} catch (Throwable $e) {
}
$state = site_state();
if ($state['released']) {
    // The newest release on GitHub, once all its files are up (or the pinned one).
    $page = mark_released($page, offered_version($state));
}
header('Content-Type: text/html; charset=utf-8');
echo $page;
