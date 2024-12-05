#!/bin/bash

# Capture Spin Variables
SPIN_ACTION=${SPIN_ACTION:-"install"}
SPIN_PHP_VERSION="${SPIN_PHP_VERSION:-8.3}"
SPIN_PHP_DOCKER_IMAGE="${SPIN_PHP_DOCKER_IMAGE:-serversideup/php:${SPIN_PHP_VERSION}-cli}"

# Set project variables
spin_template_type="open-source"
project_dir=${SPIN_PROJECT_DIRECTORY:-"$(pwd)/template"}
php_dockerfile="Dockerfile"
docker_compose_database_migration="false"

# Initialize the service variables
mariadb="1"
redis=""

###############################################
# Functions
###############################################
add_php_extensions() {
    echo "${BLUE}Adding custom PHP extensions...${RESET}"
    local dockerfile="$project_dir/$php_dockerfile"
    
    # Check if Dockerfile exists
    if [ ! -f "$dockerfile" ]; then
        echo "Error: $dockerfile not found."
        return 1
    fi
    
    # Uncomment the USER root line
    line_in_file --action replace --file "$dockerfile" "# USER root" "USER root"
    
    # Add RUN command to install extensions
    local extensions_string="${php_extensions[*]}"
    line_in_file --action replace --file "$dockerfile" "# RUN install-php-extensions" "RUN install-php-extensions $extensions_string"
    
    echo "Custom PHP extensions added."
}

process_selections() { 
    [[ $mariadb ]] && configure_mariadb
    echo "Services configured."
}

configure_mariadb() {
    # TODO
    echo "Configuring maria db."
}

select_php_extensions() {
    clear
    echo "${BOLD}${YELLOW}What PHP extensions would you like to include?${RESET}"
    echo ""
    echo "${BLUE}Default extensions:${RESET}"
    echo "ctype, curl, dom, fileinfo, filter, hash, mbstring, mysqli,"
    echo "opcache, openssl, pcntl, pcre, pdo_mysql, pdo_pgsql, redis,"
    echo "session, tokenizer, xml, zip"
    echo ""
    echo "${BLUE}See available extensions:${RESET}"
    echo "https://serversideup.net/docker-php/available-extensions"
    echo ""
    echo "Enter additional extensions as a comma-separated list (no spaces).${RESET}"
    echo "Example: gd,imagick,intl"
    echo ""
    echo "${BOLD}${YELLOW}Enter comma separated extensions below or press ${BOLD}${BLUE}ENTER${RESET} ${BOLD}${YELLOW}to use default extensions.${RESET}"
    read -r extensions_input

    # Remove spaces and split into array
    IFS=',' read -r -a php_extensions <<< "${extensions_input// /}"

    # Print selected extensions for confirmation
    while true; do
        if [ ${#php_extensions[@]} -gt 0 ]; then
            clear
            echo "${BOLD}${YELLOW}These extensions names must be supported in the PHP version you selected.${RESET}"
            echo "Learn more here: https://serversideup.net/docker-php/available-extensions"
            echo ""
            echo "${BLUE}PHP Version:${RESET} $SPIN_PHP_VERSION"
            echo "${BLUE}Extensions:${RESET}"
            for extension in "${php_extensions[@]}"; do
                echo "- $extension"
            done
            echo ""
            echo "${BOLD}${YELLOW}Are these selections correct?${RESET}"
            echo "Press ${BOLD}${BLUE}ENTER${RESET} to continue or ${BOLD}${BLUE}any other key${RESET} to go back and change selections."
            read -n 1 -s -r key
            echo

            if [[ $key == "" ]]; then
                echo "${GREEN}Continuing with selected extensions...${RESET}"
                break
            else
                echo "${YELLOW}Returning to extension selection...${RESET}"
                select_php_extensions
                return
            fi
        else
            break
        fi
    done
}

set_colors() {
    if [[ -t 1 ]]; then
        RAINBOW="
            $(printf '\033[38;5;196m')
            $(printf '\033[38;5;202m')
            $(printf '\033[38;5;226m')
            $(printf '\033[38;5;082m')
            "
        RED=$(printf '\033[31m')
        GREEN=$(printf '\033[32m')
        YELLOW=$(printf '\033[33m')
        BLUE=$(printf '\033[34m')
        DIM=$(printf '\033[2m')
        BOLD=$(printf '\033[1m')
        RESET=$(printf '\033[m')
    else
        RAINBOW=""
        RED=""
        GREEN=""
        YELLOW=""
        BLUE=""
        DIM=""
        BOLD=""
        RESET=""
    fi
}

configure_wordpress() {
    echo "Configuring WordPress..."
    source "$project_dir/configure-wordpress.sh"
    rm "$project_dir/configure-wordpress.sh"
    echo "Done configuring WordPress."
}

###############################################
# Main
###############################################

set_colors
select_php_extensions

# Clean up the screen before moving forward
clear

# Set PHP Version of Project
line_in_file --action replace --file "$project_dir/$php_dockerfile" "FROM serversideup" "FROM serversideup/php:${SPIN_PHP_VERSION}-fpm-apache AS base"

# Add PHP Extensions if available
if [ ${#php_extensions[@]} -gt 0 ]; then
    add_php_extensions
fi

# Process the user selections
process_selections

# Configure APP_URL
cp "$project_dir/.env.example" "$project_dir/.env"
configure_wordpress

# Configure Let's Encrypt
prompt_and_update_file \
    --title "🔐 Configure Let's Encrypt" \
    --details "Let's Encrypt requires an email address to send notifications about SSL renewals." \
    --prompt "Please enter your email" \
    --file "$project_dir/.infrastructure/conf/traefik/prod/traefik.yml" \
    --search-default "changeme@example.com" \
    --success-msg "Updated \".infrastructure/conf/traefik/prod/traefik.yml\" with your email."


if [[ "$SPIN_INSTALL_DEPENDENCIES" == "true" ]]; then
    if [[ "$docker_compose_database_migration" == "true" ]]; then
        initialize_database_service
    fi
fi

# Export actions so it's available to the main Spin script
export SPIN_USER_TODOS