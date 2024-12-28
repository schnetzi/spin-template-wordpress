#!/bin/bash

# Capture Spin Variables
SPIN_ACTION=${SPIN_ACTION:-"install"}
SPIN_PHP_VERSION="${SPIN_PHP_VERSION:-8.3}"
SPIN_PHP_DOCKER_IMAGE="${SPIN_PHP_DOCKER_IMAGE:-serversideup/php:${SPIN_PHP_VERSION}-cli}"

# Set project variables
project_dir=${SPIN_PROJECT_DIRECTORY:-"$(pwd)/template"}
php_dockerfile="Dockerfile"
docker_compose_database_migration="false"

# Initialize the service variables
mariadb="1"
redis=""
###############################################
# Variables
###############################################
template_src_dir=${SPIN_TEMPLATE_TEMPORARY_SRC_DIR:-"$(pwd)"}
template_src_dir_absolute=$(realpath "$template_src_dir")

# Set dependency versions
yq_version="4.44.2"

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

initialize_git_repository() {
    local current_dir=""
    current_dir=$(pwd)

    cd "$project_dir" || exit
    echo "Initializing Git repository..."
    git init

    # Exclude vendor from git
    line_in_file --file ".gitignore" \
        "/vendor"

    cd "$current_dir" || exit
}

process_selections() {
    [[ $mariadb ]] && configure_mariadb
    [[ $redis ]] && configure_redis
    echo "Services configured."
}


select_features() {
    while true; do
        clear
        echo "${BOLD}${YELLOW}Select which features you'd like to use:${RESET}"
        echo -e "${redis:+$BOLD$BLUE}1) Redis${RESET}"
        echo "Press a number to select/deselect."
        echo "Press ${BOLD}${BLUE}ENTER${RESET} to continue or skip."

        read -s -r -n 1 key
        case $key in
        1)
            [[ $redis ]] && redis="" || redis="1"
            ;;
        '') break ;;
        esac
    done
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
    IFS=',' read -r -a php_extensions <<<"${extensions_input// /}"

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
# Functions
###############################################
configure_mariadb() {
    # TODO
    echo "Configuring maria db... Done."
}

configure_redis() {
    local service_name="redis"

    merge_blocks "$service_name"

    echo "$service_name: Updating the .env and .env.example files..."
    line_in_file --action replace --file "$project_dir/.env" --file "$project_dir/.env.example" "REDIS_PASSWORD" "REDIS_PASSWORD=redispassword"
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

    echo "${BLUE}Updating files for $service_name...${RESET}"

    find "$blocks_dir" -type f | while read -r block; do
        # Extract the relative path of the file within the blocks directory
        local rel_path=${block#"$blocks_dir/"}

        # Determine the destination file
        local destination="${project_dir}/${rel_path}"

        # Create the destination directory if it doesn't exist
        mkdir -p "$(dirname "$destination")"

        # Check if the file is a YAML file
        if [[ "$block" =~ \.(yml|yaml)$ ]]; then
            # If the destination file doesn't exist, create it
            if [[ ! -f "$destination" ]]; then
                echo "{}" >"$destination"
            fi

            # Get relative paths for Docker volume mounts
            local rel_block="${block#"${template_src_dir_absolute}/"}"
            local rel_destination="${destination#"${project_dir}/"}"

            # Merge the block into the destination file, appending values
            docker run --rm \
                --user "${SPIN_USER_ID}:${SPIN_GROUP_ID}" \
                -v "${template_src_dir_absolute}:/src_dir" \
                -v "${project_dir}:/dest_dir" \
                "mikefarah/yq:$yq_version" eval-all \
                'select(fileIndex == 0) * select(fileIndex == 1)' \
                "/dest_dir/$rel_destination" "/src_dir/$rel_block" \
                -i

            echo "$service_name: Updated ${rel_path}"
        else
            # For non-YAML files, simply copy the file
            cp "$block" "$destination"
            echo "$service_name: Copied ${rel_path}"
        fi
    done
}

###############################################
# Main
###############################################

set_colors
select_php_extensions
select_features

# Clean up the screen before moving forward
clear

# Set PHP Version of Project
line_in_file --action replace --file "$project_dir/$php_dockerfile" "FROM serversideup" "FROM serversideup/php:${SPIN_PHP_VERSION}-fpm-apache AS base"

# Add environment variables
cp "$project_dir/.env.example" "$project_dir/.env"

# Add PHP Extensions if available
if [ ${#php_extensions[@]} -gt 0 ]; then
    add_php_extensions
fi

# Install Composer dependencies
if [[ "$SPIN_INSTALL_DEPENDENCIES" == "true" ]]; then
    docker pull "$SPIN_PHP_DOCKER_IMAGE"

    if [[ "$SPIN_ACTION" == "init" ]]; then
        echo "Re-installing composer dependencies..."
        (cd $project_dir && spin run php composer install)
    else
        echo "Installing Dependencies..."
        (cd $project_dir && spin run php composer require vlucas/phpdotenv)
        (cd $project_dir && spin run php composer require serversideup/spin --dev)
    fi
fi

# Process the user selections
process_selections

# Configure APP_URL
configure_wordpress

# Configure Server Contact
line_in_file --action exact --ignore-missing --file "$project_dir/.infrastructure/conf/traefik/prod/traefik.yml" "changeme@example.com" "$SERVER_CONTACT"
line_in_file --action exact --ignore-missing --file "$project_dir/.spin.yml" "changeme@example.com" "$SERVER_CONTACT"

if [[ ! -d "$project_dir/.git" ]]; then
    initialize_git_repository
fi

# Export actions so it's available to the main Spin script
export SPIN_USER_TODOS
