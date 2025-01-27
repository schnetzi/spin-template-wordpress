<?php

use Dotenv\Dotenv;

$appEnv = getenv('APP_ENV') ?? null;

$envFile = '.env';

if ($appEnv) {
    $possibleEnvFile = '.env.' . $appEnv;

    if (file_exists(dirname(__DIR__) . '/' . $possibleEnvFile)) {
        $envFile = $possibleEnvFile;
    }
}

$dotenv = Dotenv::createMutable(dirname(__DIR__), $envFile);
$dotenv->safeLoad();
