#!/bin/bash

# Capture Spin Variables
SPIN_ACTION=${SPIN_ACTION:-"install"}
SPIN_PHP_VERSION="${SPIN_PHP_VERSION:-8.5}"
SPIN_PHP_VARIATION="${SPIN_PHP_VARIATION:-fpm-apache}"
SPIN_PHP_DOCKER_INSTALLER_IMAGE="${SPIN_PHP_DOCKER_INSTALLER_IMAGE:-serversideup/php:${SPIN_PHP_VERSION}-cli}"
SPIN_PHP_DOCKER_BASE_IMAGE="${SPIN_PHP_DOCKER_BASE_IMAGE:-serversideup/php:${SPIN_PHP_VERSION}-${SPIN_PHP_VARIATION}}"

# Set project variables
project_dir=${SPIN_PROJECT_DIRECTORY:-"$(pwd)/template"}
php_dockerfile="Dockerfile"
template_src_dir=${SPIN_TEMPLATE_TEMPORARY_SRC_DIR:-"$(pwd)"}
template_src_dir_absolute=$(realpath "$template_src_dir")

# Initialize the service variables
mariadb="1"
mysql=""
redis=""
use_github_actions=""

# Default WordPress Extensions
php_extensions=("gd" "exif" "intl" "imagick")

###############################################
# Functions
###############################################

set_colors() {
    if [[ -t 1 ]]; then
        RED=$(printf '\033[31m')
        GREEN=$(printf '\033[32m')
        YELLOW=$(printf '\033[33m')
        BLUE=$(printf '\033[34m')
        DIM=$(printf '\033[2m')
        BOLD=$(printf '\033[1m')
        RESET=$(printf '\033[m')
    else
        RED="" GREEN="" YELLOW="" BLUE="" DIM="" BOLD="" RESET=""
    fi
}

array_contains() {
    local needle="$1"; shift
    local item
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

ensure_frankenphp_mysql_extensions() {
    if [[ "$SPIN_PHP_VARIATION" == *"frankenphp"* ]]; then
        echo "${BLUE}FrankenPHP variation detected — ensuring MySQL PHP extensions are installed (mysqli, pdo_mysql)...${RESET}"

        array_contains "mysqli" "${php_extensions[@]}" || php_extensions+=("mysqli")
        array_contains "pdo_mysql" "${php_extensions[@]}" || php_extensions+=("pdo_mysql")
    fi
}

add_php_extensions() {
    echo "${BLUE}Adding custom PHP extensions...${RESET}"
    local dockerfile="$project_dir/$php_dockerfile"

    # Check if Dockerfile exists
    if [ ! -f "$dockerfile" ]; then
        echo "Error: $dockerfile not found."
        return 1
    fi

    # Add RUN command to install extensions
    local extensions_string="${php_extensions[*]}"
    line_in_file --action replace --file "$dockerfile" "# RUN install-php-extensions" "RUN install-php-extensions $extensions_string"

    echo "Custom PHP extensions added: $extensions_string"
}

add_apache_remoteip_config() {
    # Only apply to Apache-based variations
    if [[ "$SPIN_PHP_VARIATION" != *"apache"* ]]; then
        return 0
    fi

    echo "${BLUE}Apache variation detected — enabling RemoteIP module...${RESET}"

    local dockerfile="$project_dir/$php_dockerfile"

    if [ ! -f "$dockerfile" ]; then
        echo "Error: $dockerfile not found."
        return 1
    fi

    awk '
      $0 ~ /^# SPIN_APACHE_REMOTEIP_BLOCK$/ {
        print "RUN a2enmod remoteip headers"
        print "COPY ./.infrastructure/conf/apache/remoteip.conf /etc/apache2/conf-available/remoteip.conf"
        print "RUN a2enconf remoteip"
        next
      }
      { print }
    ' "$dockerfile" > "${dockerfile}.tmp" && mv "${dockerfile}.tmp" "$dockerfile"
}

initialize_git_repository() {
    local current_dir=""
    current_dir=$(pwd)

    cd "$project_dir" || exit
    echo "Initializing Git repository..."
    git init

    configure_gitignore

    cd "$current_dir" || exit
}

select_database() {
    while true; do
        clear
        echo "${BOLD}${YELLOW}Which database engine would you like to use?${RESET}"
        echo -e "${mariadb:+$BOLD$BLUE}1) MariaDB (Default)${RESET}"
        echo -e "${mysql:+$BOLD$BLUE}2) MySQL${RESET}"
        echo ""
        echo "Press a number to toggle. Press ${BOLD}${BLUE}ENTER${RESET} to continue."

        read -s -n 1 key
        case $key in
        1)
            mariadb="1"
            mysql=""
            ;;
        2)
            mariadb=""
            mysql="1"
            ;;
        '') break ;;
        esac
    done
}

select_php_extensions() {
    clear
    echo "${BOLD}${YELLOW}Additional PHP extensions?${RESET}"
    echo ""
    echo "${BLUE}Default extensions already included:${RESET}"
    echo "${php_extensions[*]}"
    if [[ "$SPIN_PHP_VARIATION" == *"frankenphp"* ]]; then
        echo ""
        echo "${DIM}Automatically added for FrankenPHP:${RESET}"
        echo "${DIM}- mysqli${RESET}"
        echo "${DIM}- pdo_mysql${RESET}"
    fi
    echo ""
    echo "${BLUE}See available extensions:${RESET}"
    echo "https://serversideup.net/docker-php/available-extensions"
    echo ""
    echo "Enter additional extensions (comma-separated, no spaces) or press ${BOLD}${BLUE}ENTER${RESET} to keep defaults."
    read -r extensions_input

    if [[ -n "$extensions_input" ]]; then
        IFS=',' read -r -a additional_exts <<<"${extensions_input// /}"
        php_extensions+=("${additional_exts[@]}")
    fi
}

configure_mariadb() {
    local service_name="mariadb"
    merge_blocks "$service_name"

    line_in_file --action replace --file "$project_dir/.env" --file "$project_dir/.env.example" "DATABASE_HOST" "DATABASE_HOST=$service_name"
    echo "Configuring MariaDB... Done."
}

configure_mysql() {
    local service_name="mysql"
    merge_blocks "$service_name"

    line_in_file --action replace --file "$project_dir/.env" --file "$project_dir/.env.example" "DATABASE_HOST" "DATABASE_HOST=$service_name"
    echo "Configuring MySQL... Done."
}

configure_wordpress() {
    echo "Configuring WordPress..."
    # Support for the custom WordPress config script in your template
    if [ -f "$project_dir/configure-wordpress.sh" ]; then
        source "$project_dir/configure-wordpress.sh"
        rm "$project_dir/configure-wordpress.sh"
    fi

    [ -f "$project_dir/load-environment.php" ] && mv "$project_dir/load-environment.php" "$project_dir/public/load-environment.php"

    echo "Done configuring WordPress."
}

configure_gitignore() {
    local ignore_content
    ignore_content="# secrets / infra
# secrets / env
.vault-password
.spin.yml
.env*
!.env.example

# dependencies
/vendor

# WordPress runtime data (never in Git)
public/wp-content/uploads/*
!public/wp-content/uploads/.gitkeep

public/wp-content/cache
public/wp-content/wp-rocket-config
public/wp-content/upgrade
public/wp-content/ai1wm-backups
public/wp-content/backups

# Optional: logs if any plugin writes them
public/wp-content/*.log"

    # Write it to the destination
    echo "$ignore_content" > "$project_dir/.gitignore"
}

configure_dockerignore() {
    local ignore_content
    ignore_content="# secrets / infra
.vault-password
.git
.github
.gitlab-ci.yml
.spin*
.infrastructure
!.infrastructure/**/local-ca.pem
!.infrastructure/conf/apache/**
!.infrastructure/conf/frankenphp/**

# docker files
Dockerfile
docker-*.yml

# WordPress runtime artifacts (never in image)
public/wp-content/uploads
public/wp-content/cache
public/wp-content/wp-rocket-config
public/wp-content/upgrade
public/wp-content/ai1wm-backups
public/wp-content/backups

# Keep immutable WP assets in the image
!public/wp-content/languages
!public/wp-content/plugins
!public/wp-content/themes
!public/wp-content/object-cache.php"

    # Write it to the destination
    echo "$ignore_content" > "$project_dir/.dockerignore"
}

configure_redis() {
    local service_name="redis"

    merge_blocks "$service_name"

    echo "$service_name: Updating the .env and .env.example files..."
    line_in_file --action replace --file "$project_dir/.env" --file "$project_dir/.env.example" "REDIS_PASSWORD" "REDIS_PASSWORD=redispassword"
}

docker_yq() {
    local yq_version="4.44.2"
    docker run --rm \
        --user "${SPIN_USER_ID}:${SPIN_GROUP_ID}" \
        -v "${project_dir}:/workdir" \
        -v "${template_src_dir_absolute}:/src" \
        "mikefarah/yq:$yq_version" \
        "$@"
}

merge_blocks() {
    local service_name=$1
    local blocks_dir="$template_src_dir_absolute/blocks/$service_name"

    if [[ ! -d $blocks_dir ]]; then
        echo "${BOLD}${RED}The blocks directory for \"$service_name\" does not exist. Exiting...${RESET}"
        echo "Could not find the blocks directory at:"
        echo "$blocks_dir"
        exit 1
    fi

    echo "${BLUE}Merging configuration for $service_name...${RESET}"
    find "$blocks_dir" -type f | while read -r block; do
        # Extract the relative path of the file within the blocks directory
        local rel_path=${block#"$blocks_dir/"}

        # Determine the destination file
        local destination="${project_dir}/${rel_path}"

        # Create the destination directory if it doesn't exist
        mkdir -p "$(dirname "$destination")"

        # Check if the file is a YAML file
        if [[ "$block" =~ \.(yml|yaml)$ ]]; then
            [[ ! -f "$destination" ]] && echo "{}" >"$destination"
            local rel_block="${block#"${template_src_dir_absolute}/"}"
            local rel_destination="${destination#"${project_dir}/"}"
            docker_yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "/workdir/$rel_destination" "/src/$rel_block" -i
        else
            # For non-YAML files, simply copy the file
            cp "$block" "$destination"
            echo "$service_name: Copied ${rel_path}"
        fi
    done
}

process_selections() {
    [[ $mysql ]] && configure_mysql
    [[ $mariadb ]] && configure_mariadb
    [[ $redis ]] && configure_redis
    [[ $use_github_actions ]] && merge_blocks "github-actions"
}

###############################################
# Main
###############################################

set_colors
select_php_extensions
select_database

# Redis Selection
while true; do
    clear
    echo "${BOLD}${YELLOW}Optional Features:${RESET}"
    echo -e "${redis:+$BOLD$BLUE}1) Redis${RESET}"
    echo -e "${use_github_actions:+$BOLD$BLUE}2) GitHub Actions${RESET}"
    echo "Press number to toggle. Press ENTER to continue."
    read -s -r -n 1 key
    case $key in
        1) [[ $redis ]] && redis="" || redis="1" ;;
        2) [[ $use_github_actions ]] && use_github_actions="" || use_github_actions="1" ;;
        '') break ;;
    esac
done

clear

# Set the Base Image in Dockerfile
line_in_file --action replace --file "$project_dir/$php_dockerfile" "FROM serversideup" "FROM ${SPIN_PHP_DOCKER_BASE_IMAGE} AS base"

# Add environment variables
cp "$project_dir/.env.example" "$project_dir/.env"
configure_dockerignore

# Apache-specific config
add_apache_remoteip_config

# ensure FrankenPHP includes DB drivers before writing Dockerfile
ensure_frankenphp_mysql_extensions

# Add PHP Extensions
add_php_extensions

# Handle Dependencies
if [[ "$SPIN_INSTALL_DEPENDENCIES" == "true" ]]; then
    echo "Installing Composer dependencies..."
    docker pull "$SPIN_PHP_DOCKER_INSTALLER_IMAGE"
    (cd "$project_dir" && spin run php composer require vlucas/phpdotenv)
    (cd "$project_dir" && spin run php composer require serversideup/spin --dev)
fi

# 4. Process Docker Compose Merges
process_selections

# Finalize WordPress
configure_wordpress

# Configure Server Contact
line_in_file --action exact --ignore-missing --file "$project_dir/.infrastructure/conf/traefik/prod/traefik.yml" "changeme@example.com" "$SERVER_CONTACT"
line_in_file --action exact --ignore-missing --file "$project_dir/.spin.yml" "changeme@example.com" "$SERVER_CONTACT"

if [[ ! -d "$project_dir/.git" ]]; then
    initialize_git_repository
fi

# Export actions so it's available to the main Spin script
export SPIN_USER_TODOS
