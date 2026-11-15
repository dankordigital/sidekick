<?php
// Copy this file to wishlist-config.php (next to wishlist.php on the
// hosting, never into git) and put in the password of the mailbox the
// wishlist emails come from (info@getsidekick.app). The website can't show
// this file: PHP runs it and prints nothing.
return [
    'smtp_password' => '',
    // Optional: Cloudflare Turnstile for the bot check (gate.php). Free at
    // dash.cloudflare.com → Turnstile → Add site (getsidekick.app); paste
    // both keys. Empty: Sidekick's own "I'm not a robot" puzzle is used.
    'turnstile_site_key' => '',
    'turnstile_secret' => '',
];
