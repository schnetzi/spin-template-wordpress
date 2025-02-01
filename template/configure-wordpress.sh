#!/bin/bash

if [ -f "$project_dir/public/wp-config.php" ]; then
    echo "Already existing wp-config.php. Do not overwrite."
    return 0
fi

redisConfig=""

if [ -n "$redis" ]; then
  redisConfig=$(cat <<EOL

/** Redis */
define('WP_REDIS_HOST', 'redis');
define('WP_REDIS_PORT', '6379');
defined('WP_REDIS_PASSWORD') or define('WP_REDIS_PASSWORD', \$_ENV['REDIS_PASSWORD']);
EOL
)
fi

salts=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)

cat <<EOF >"$project_dir/public/wp-config.php"
<?php
/** @desc this loads the composer autoload file */
require_once dirname( __DIR__ ) . '/vendor/autoload.php';
require_once dirname( __DIR__ ) . '/public/load-environment.php';

/**
 * The base configuration for WordPress
 *
 * The wp-config.php creation script uses this file during the installation.
 * You don't have to use the website, you can copy this file to "wp-config.php"
 * and fill in the values.
 *
 * This file contains the following configurations:
 *
 * * Database settings
 * * Secret keys
 * * Database table prefix
 * * ABSPATH
 *
 * @link https://developer.wordpress.org/advanced-administration/wordpress/wp-config/
 *
 * @package WordPress
 */

// ** Database settings - You can get this info from your web host ** //
/** The name of the database for WordPress */
defined('DB_NAME') or define('DB_NAME', \$_ENV['MARIADB_DATABASE']);

/** Database username */
defined('DB_USER') or define('DB_USER', \$_ENV['MARIADB_USER']);

/** Database password */
defined('DB_PASSWORD') or define('DB_PASSWORD', \$_ENV['MARIADB_PASSWORD']);

/** Database hostname */
define( 'DB_HOST', 'mariadb' );

/** Database charset to use in creating database tables. */
define( 'DB_CHARSET', 'utf8' );

/** The database collate type. Don't change this if in doubt. */
define( 'DB_COLLATE', '' );

/** WordPress Tweaks */
defined('WP_HOME') or define('WP_HOME', \$_ENV['APP_URL']);
defined('WP_SITEURL') or define('WP_SITEURL', \$_ENV['APP_URL']);
define( 'FORCE_SSL_ADMIN', true );
// define( 'WP_MEMORY_LIMIT', '256M' );

// Disallow file modifications
define('DISALLOW_FILE_MODS', true);
$redisConfig

/**#@+
 * Authentication unique keys and salts.
 *
 * Change these to different unique phrases! You can generate these using
 * the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}.
 *
 * You can change these at any point in time to invalidate all existing cookies.
 * This will force all users to have to log in again.
 *
 * @since 2.6.0
 */

$salts

/**
 * WordPress database table prefix.
 *
 * You can have multiple installations in one database if you give each
 * a unique prefix. Only numbers, letters, and underscores please!
 *
 * At the installation time, database tables are created with the specified prefix.
 * Changing this value after WordPress is installed will make your site think
 * it has not been installed.
 *
 * @link https://developer.wordpress.org/advanced-administration/wordpress/wp-config/#table-prefix
 */
\$table_prefix = 'wp_';

/**
 * For developers: WordPress debugging mode.
 *
 * Change this to true to enable the display of notices during development.
 * It is strongly recommended that plugin and theme developers use WP_DEBUG
 * in their development environments.
 *
 * For information on other constants that can be used for debugging,
 * visit the documentation.
 *
 * @link https://developer.wordpress.org/advanced-administration/debug/debug-wordpress/
 */
define('WP_DEBUG', false);

/**
 * Custom code for docker traefik wordpress
 */
if (\$_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https')
    \$_SERVER['HTTPS']='on';

if (isset(\$_SERVER['HTTP_X_FORWARDED_HOST'])) {
    \$_SERVER['HTTP_HOST'] = \$_SERVER['HTTP_X_FORWARDED_HOST'];
}

/* Add any custom values between this line and the "stop editing" line. */



/* That's all, stop editing! Happy publishing. */

/** Absolute path to the WordPress directory. */
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ . '/' );
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';
EOF
