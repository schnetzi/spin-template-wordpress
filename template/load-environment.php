<?php

use Dotenv\Dotenv;

$appEnv = getenv('APP_ENV') ?? null;

$envFile = '.env';

if ($appEnv) {
    $envFile = '.env.' . $appEnv;
}

// Load the environment specific file and override current values
$dotenv = Dotenv::createMutable(dirname(__DIR__), $envFile);
$dotenv->safeLoad();
