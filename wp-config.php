<?php
// Database — plain env vars (non-sensitive) + DB_PASSWORD from Secrets Manager
define('DB_NAME',     getenv('DB_NAME')     ?: 'wordpress');
define('DB_USER',     getenv('DB_USER')     ?: 'wordpress');
define('DB_PASSWORD', getenv('DB_PASSWORD') ?: '');
define('DB_HOST',     getenv('DB_HOST')     ?: 'localhost');
define('DB_CHARSET',  'utf8mb4');
define('DB_COLLATE',  '');

// Auth keys & salts — injected from Secrets Manager as WP_SALTS (JSON blob)
$_salts = json_decode(getenv('WP_SALTS') ?: '{}', true);
define('AUTH_KEY',         $_salts['auth_key']         ?? 'change-me');
define('SECURE_AUTH_KEY',  $_salts['secure_auth_key']  ?? 'change-me');
define('LOGGED_IN_KEY',    $_salts['logged_in_key']    ?? 'change-me');
define('NONCE_KEY',        $_salts['nonce_key']        ?? 'change-me');
define('AUTH_SALT',        $_salts['auth_salt']        ?? 'change-me');
define('SECURE_AUTH_SALT', $_salts['secure_auth_salt'] ?? 'change-me');
define('LOGGED_IN_SALT',   $_salts['logged_in_salt']   ?? 'change-me');
define('NONCE_SALT',       $_salts['nonce_salt']       ?? 'change-me');

$table_prefix = getenv('WP_TABLE_PREFIX') ?: 'wp_';

// Debug — on only in development
$_wp_env = getenv('WP_ENV') ?: 'production';
define('WP_DEBUG',         $_wp_env === 'development');
define('WP_DEBUG_LOG',     $_wp_env === 'development');
define('WP_DEBUG_DISPLAY', false);
define('SCRIPT_DEBUG',     $_wp_env === 'development');

// Trust ALB's forwarded proto header so WordPress generates https:// URLs
if (
    isset($_SERVER['HTTP_X_FORWARDED_PROTO']) &&
    $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https'
) {
    $_SERVER['HTTPS'] = 'on';
}

// Optional: override site URLs per environment (set via ECS task env vars)
if ($url = getenv('WP_SITEURL')) { define('WP_SITEURL', $url); }
if ($url = getenv('WP_HOME'))    { define('WP_HOME',    $url); }

define('WP_MEMORY_LIMIT',          '256M');
define('AUTOMATIC_UPDATER_DISABLED', true);
define('DISALLOW_FILE_EDIT',         true);

if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}
require_once ABSPATH . 'wp-settings.php';
