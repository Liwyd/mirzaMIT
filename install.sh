#!/bin/bash

# ============================================================================
# MIT VPN Bot Installer
# https://t.me/MITvpn
# https://t.me/MITsupports
# ============================================================================

# Checking Root Access
if [[ $EUID -ne 0 ]]; then
    echo -e "\033[31m[ERROR]\033[0m Please run this script as \033[1mroot\033[0m."
    exit 1
fi

# Check SSL certificate status and days remaining
check_ssl_status() {
    local config_found=false
    for cfg in /var/www/html/mitbot*/config.php; do
        if [ -f "$cfg" ]; then
            config_found=true
            domain=$(grep '^\$domainhosts' "$cfg" | cut -d"'" -f2 | cut -d'/' -f1)
            if [ -n "$domain" ] && [ -f "/etc/letsencrypt/live/$domain/cert.pem" ]; then
                expiry_date=$(openssl x509 -enddate -noout -in "/etc/letsencrypt/live/$domain/cert.pem" | cut -d= -f2)
                current_date=$(date +%s)
                expiry_timestamp=$(date -d "$expiry_date" +%s)
                days_remaining=$(( ($expiry_timestamp - $current_date) / 86400 ))
                if [ $days_remaining -gt 0 ]; then
                    echo -e "\033[32m✅ SSL Certificate: $days_remaining days remaining (Domain: $domain)\033[0m"
                else
                    echo -e "\033[31m❌ SSL Certificate: Expired (Domain: $domain)\033[0m"
                fi
            fi
        fi
    done
    if [ "$config_found" = false ]; then
        echo -e "\033[33m⚠️ Cannot check SSL: No config file found\033[0m"
    fi
}

# Check bot installation status
check_bot_status() {
    local found=false
    for cfg in /var/www/html/mitbot*/config.php; do
        if [ -f "$cfg" ]; then
            found=true
            local dir=$(dirname "$cfg")
            local name=$(basename "$dir")
            echo -e "\033[32m✅ Bot installed: $name\033[0m"
        fi
    done
    if [ "$found" = false ]; then
        echo -e "\033[31m❌ Bot is not installed\033[0m"
    fi
    check_ssl_status
}

# Display Logo
function show_logo() {
    clear
    echo -e "\033[1;34m"
    echo "================================================================================="
    echo " ███╗   ███╗██╗██████╗ ███████╗ █████╗  ██████╗  █████╗ ███╗   ██╗███████╗██╗   "
    echo " ████╗ ████║██║██╔══██╗╚══███╔╝██╔══██╗ ██╔══██╗██╔══██╗████╗  ██║██╔════╝██║   "
    echo " ██╔████╔██║██║██████╔╝  ███╔╝ ███████║ ██████╔╝███████║██╔██╗ ██║█████╗  ██║   "
    echo " ██║╚██╔╝██║██║██╔══██╗ ███╔╝  ██╔══██║ ██╔═══╝ ██╔══██║██║╚██╗██║██╔══╝  ██║   "
    echo " ██║ ╚═╝ ██║██║██║  ██║███████╗██║  ██║ ██║     ██║  ██║██║ ╚████║███████╗█████╗"
    echo " ╚═╝     ╚═╝╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚════╝"
    echo "================================================================================="
    echo -e "\033[0m"
    echo ""
    echo -e "\033[1;36mVersion:\033[0m \033[33m6.0.0\033[0m"
    echo -e "\033[1;36mTelegram Channel:\033[0m \033[34mhttps://t.me/MITvpn\033[0m"
    echo -e "\033[1;36mTelegram Group:  \033[0m \033[34mhttps://t.me/MITsupports\033[0m"
    echo ""
    echo -e "\033[1;36mInstallation Status:\033[0m"
    check_bot_status
    echo ""
}


# Display Menu
function show_menu() {
    show_logo
    echo -e "\033[1;36m1)\033[0m Install MIT VPN Bot"
    echo -e "\033[1;36m2)\033[0m Update MIT VPN Bot"
    echo -e "\033[1;36m3)\033[0m Remove MIT VPN Bot"
    echo -e "\033[1;36m4)\033[0m Export Database"
    echo -e "\033[1;36m5)\033[0m Import Database"
    echo -e "\033[1;36m6)\033[0m Configure Automated Backup"
    echo -e "\033[1;36m7)\033[0m Renew SSL Certificates"
    echo -e "\033[1;36m8)\033[0m Change Domain"
    echo -e "\033[1;36m9)\033[0m Additional Bot Management"
    echo -e "\033[1;36m10)\033[0m Exit"
    echo ""
    read -p "Select an option [1-10]: " option
    case $option in
        1) install_bot ;;
        2) update_bot ;;
        3) remove_bot ;;
        4) export_database ;;
        5) import_database ;;
        6) auto_backup ;;
        7) renew_ssl ;;
        8) change_domain ;;
        9) manage_additional_bots ;;
        10)
            echo -e "\033[32mExiting...\033[0m"
            exit 0
            ;;
        *)
            echo -e "\033[31mInvalid option. Please try again.\033[0m"
            show_menu
            ;;
    esac
}

# Check if Marzban is installed
function check_marzban_installed() {
    if [ -f "/opt/marzban/docker-compose.yml" ]; then
        return 0  # Marzban installed
    else
        return 1  # Marzban not installed
    fi
}

# Detect database type for Marzban
function detect_database_type() {
    COMPOSE_FILE="/opt/marzban/docker-compose.yml"
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "unknown"  # File not found, cannot determine database type
        return 1
    fi
    if grep -q "^[[:space:]]*mysql:" "$COMPOSE_FILE"; then
        echo "mysql"
        return 0
    elif grep -q "^[[:space:]]*mariadb:" "$COMPOSE_FILE"; then
        echo "mariadb"
        return 1
    else
        echo "sqlite"  # Assume SQLite if neither MySQL nor MariaDB is found
        return 1
    fi
}

# Find a free port between 3300 and 3330
function find_free_port() {
    for port in {3300..3330}; do
        if ! ss -tuln | grep -q ":$port "; then
            echo "$port"
            return 0
        fi
    done
    echo -e "\033[31m[ERROR] No free port found between 3300 and 3330.\033[0m"
    exit 1
}
# Function to fix update issues by changing mirrors
function fix_update_issues() {
    echo -e "\e[33mTrying to fix update issues by changing mirrors...\033[0m"

    # Backup original sources.list
    cp /etc/apt/sources.list /etc/apt/sources.list.backup

    # Detect Ubuntu version
    if [ -f /etc/os-release ]; then
        . /etc/apt/sources.list
        VERSION_ID=$(cat /etc/os-release | grep VERSION_ID | cut -d '"' -f2)
        UBUNTU_CODENAME=$(cat /etc/os-release | grep UBUNTU_CODENAME | cut -d '=' -f2)
    else
        echo -e "\e[91mCould not detect Ubuntu version.\033[0m"
        return 1
    fi

    # Try different mirrors
    MIRRORS=(
        "archive.ubuntu.com"
        "us.archive.ubuntu.com"
        "fr.archive.ubuntu.com"
        "de.archive.ubuntu.com"
        "mirrors.digitalocean.com"
        "mirrors.linode.com"
    )

    for mirror in "${MIRRORS[@]}"; do
        echo -e "\e[33mTrying mirror: $mirror\033[0m"
        # Create new sources.list
        cat > /etc/apt/sources.list << EOF
deb http://$mirror/ubuntu/ $UBUNTU_CODENAME main restricted universe multiverse
deb http://$mirror/ubuntu/ $UBUNTU_CODENAME-updates main restricted universe multiverse
deb http://$mirror/ubuntu/ $UBUNTU_CODENAME-security main restricted universe multiverse
EOF

        # Try updating
        if apt-get update 2>/dev/null; then
            echo -e "\e[32mSuccessfully updated using mirror: $mirror\033[0m"
            return 0
        fi
    done

    # If all mirrors fail, restore original sources.list
    mv /etc/apt/sources.list.backup /etc/apt/sources.list
    echo -e "\e[91mAll mirrors failed. Restored original sources.list\033[0m"
    return 1
}

# Install Function
function install_bot() {
    echo -e "\e[32mInstalling MIT script ... \033[0m\n"

    # Detect existing instances and suggest next number
    N=1
    while [ -d "/var/www/html/mitbot${N}" ]; do
        N=$((N + 1))
    done
    BOT_DIR="/var/www/html/mitbot${N}"
    DBNAME="mitbot${N}"

    # Check if Marzban is installed and redirect to appropriate function
    if check_marzban_installed; then
        echo -e "\033[41m[IMPORTANT WARNING]\033[0m \033[1;33mMarzban detected. Proceeding with Marzban-compatible installation.\033[0m"
        install_bot_with_marzban "$@"  # Pass any arguments (e.g., -v beta)
        return 0
    fi

    # Function to add the Ondřej Surý PPA for PHP
    add_php_ppa() {
        sudo add-apt-repository -y ppa:ondrej/php || {
            echo -e "\e[91mError: Failed to add PPA ondrej/php.\033[0m"
            return 1
        }
    }

    # Function to add the Ondřej Surý PPA for PHP with locale override
    add_php_ppa_with_locale() {
        sudo LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php || {
            echo -e "\e[91mError: Failed to add PPA ondrej/php with locale override.\033[0m"
            return 1
        }
    }

    # Try adding the PPA with the system's default locale settings
    if ! add_php_ppa; then
        echo "Failed to add PPA with default locale, retrying with locale override..."
        if ! add_php_ppa_with_locale; then
            echo "Failed to add PPA even with locale override. Exiting..."
            exit 1
        fi
    fi

    # Try normal update/upgrade first
    if ! (sudo apt update && sudo apt upgrade -y); then
        echo -e "\e[93mUpdate/upgrade failed. Attempting to fix using alternative mirrors...\033[0m"
        if fix_update_issues; then
            # Try update/upgrade again after fixing mirrors
            if sudo apt update && sudo apt upgrade -y; then
                echo -e "\e[92mThe server was successfully updated after fixing mirrors...\033[0m\n"
            else
                echo -e "\e[91mError: Failed to update even after trying alternative mirrors.\033[0m"
                exit 1
            fi
        else
            echo -e "\e[91mError: Failed to update/upgrade packages and mirror fix failed.\033[0m"
            exit 1
        fi
    else
        echo -e "\e[92mThe server was successfully updated ...\033[0m\n"
    fi

    sudo apt-get install software-properties-common || {
        echo -e "\e[91mError: Failed to install software-properties-common.\033[0m"
        exit 1
    }

    sudo apt install -y git unzip curl || {
        echo -e "\e[91mError: Failed to install required packages.\033[0m"
        exit 1
    }

    DEBIAN_FRONTEND=noninteractive sudo apt install -y php8.2 php8.2-fpm php8.2-mysql || {
        echo -e "\e[91mError: Failed to install PHP 8.2 and related packages.\033[0m"
        exit 1
    }

    # List of required packages
    PKG=(
        lamp-server^
        libapache2-mod-php8.2
        mysql-server
        apache2
        php8.2-mbstring
        php8.2-zip
        php8.2-gd
        php8.2-json
        php8.2-curl
    )

    # Installing required packages with error handling
    for i in "${PKG[@]}"; do
        dpkg -s $i &>/dev/null
        if [ $? -eq 0 ]; then
            echo "$i is already installed"
        else
            if ! DEBIAN_FRONTEND=noninteractive sudo apt install -y $i; then
                echo -e "\e[91mError installing $i. Exiting...\033[0m"
                exit 1
            fi
        fi
    done

    echo -e "\n\e[92mPackages Installed, Continuing ...\033[0m\n"

    # phpMyAdmin Configuration
    echo 'phpmyadmin phpmyadmin/dbconfig-install boolean true' | sudo debconf-set-selections
    echo 'phpmyadmin phpmyadmin/app-password-confirm password mitpass' | sudo debconf-set-selections
    echo 'phpmyadmin phpmyadmin/mysql/admin-pass password mitpass' | sudo debconf-set-selections
    echo 'phpmyadmin phpmyadmin/mysql/app-pass password mitpass' | sudo debconf-set-selections
    echo 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2' | sudo debconf-set-selections

    sudo apt-get install phpmyadmin -y || {
        echo -e "\e[91mError: Failed to install phpMyAdmin.\033[0m"
        exit 1
    }
    # Check and remove existing phpMyAdmin configuration
    if [ -f /etc/apache2/conf-available/phpmyadmin.conf ]; then
        sudo rm -f /etc/apache2/conf-available/phpmyadmin.conf && echo -e "\e[92mRemoved existing phpMyAdmin configuration.\033[0m"
    fi

    # Create symbolic link for phpMyAdmin configuration
    sudo ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf || {
        echo -e "\e[91mError: Failed to create symbolic link for phpMyAdmin configuration.\033[0m"
        exit 1
    }

    sudo a2enconf phpmyadmin.conf || {
        echo -e "\e[91mError: Failed to enable phpMyAdmin configuration.\033[0m"
        exit 1
    }
    sudo systemctl restart apache2 || {
        echo -e "\e[91mError: Failed to restart Apache2 service.\033[0m"
        exit 1
    }

    # Additional package installations with error handling
    sudo apt-get install -y php8.2-soap || {
        echo -e "\e[91mError: Failed to install php8.2-soap.\033[0m"
        exit 1
    }

    sudo apt-get install libapache2-mod-php8.2 || {
        echo -e "\e[91mError: Failed to install libapache2-mod-php8.2.\033[0m"
        exit 1
    }

    sudo systemctl enable mysql.service || {
        echo -e "\e[91mError: Failed to enable MySQL service.\033[0m"
        exit 1
    }
    sudo systemctl start mysql.service || {
        echo -e "\e[91mError: Failed to start MySQL service.\033[0m"
        exit 1
    }
    sudo systemctl enable apache2 || {
        echo -e "\e[91mError: Failed to enable Apache2 service.\033[0m"
        exit 1
    }
    sudo systemctl start apache2 || {
        echo -e "\e[91mError: Failed to start Apache2 service.\033[0m"
        exit 1
    }

    sudo apt-get install ufw -y || {
        echo -e "\e[91mError: Failed to install UFW.\033[0m"
        exit 1
    }
    ufw allow 'Apache' || {
        echo -e "\e[91mError: Failed to allow Apache in UFW.\033[0m"
        exit 1
    }
    sudo systemctl restart apache2 || {
        echo -e "\e[91mError: Failed to restart Apache2 service after UFW update.\033[0m"
        exit 1
    }

    sudo apt-get install -y git || {
        echo -e "\e[91mError: Failed to install Git.\033[0m"
        exit 1
    }
    sudo apt-get install -y wget || {
        echo -e "\e[91mError: Failed to install Wget.\033[0m"
        exit 1
    }
    sudo apt-get install -y unzip || {
        echo -e "\e[91mError: Failed to install Unzip.\033[0m"
        exit 1
    }
    sudo apt install curl -y || {
        echo -e "\e[91mError: Failed to install cURL.\033[0m"
        exit 1
    }
    sudo apt-get install -y php8.2-ssh2 || {
        echo -e "\e[91mError: Failed to install php8.2-ssh2.\033[0m"
        exit 1
    }
    sudo apt-get install -y libssh2-1-dev libssh2-1 || {
        echo -e "\e[91mError: Failed to install libssh2.\033[0m"
        exit 1
    }
    sudo apt install jq -y || {
        echo -e "\e[91mError: Failed to install jq.\033[0m"
        exit 1
    }

    sudo systemctl restart apache2.service || {
        echo -e "\e[91mError: Failed to restart Apache2 service.\033[0m"
        exit 1
    }

    # Check and remove existing directory before cloning Git repository
    if [ -d "$BOT_DIR" ]; then
        echo -e "\e[93mDirectory $BOT_DIR already exists. Removing...\033[0m"
        sudo rm -rf "$BOT_DIR" || {
            echo -e "\e[91mError: Failed to remove existing directory $BOT_DIR.\033[0m"
            exit 1
        }
    fi

    # Create bot directory
    sudo mkdir -p "$BOT_DIR"
    if [ ! -d "$BOT_DIR" ]; then
        echo -e "\e[91mError: Failed to create directory $BOT_DIR.\033[0m"
        exit 1
    fi

    # Default to latest release
    ZIP_URL=$(curl -s https://api.github.com/repos/Liwyd/mirzaMIT/releases/latest | grep "zipball_url" | cut -d '"' -f 4)

# Check for version flag
if [[ "$1" == "-v" && "$2" == "beta" ]] || [[ "$1" == "-beta" ]] || [[ "$1" == "-" && "$2" == "beta" ]]; then
    ZIP_URL="https://github.com/Liwyd/mirzaMIT/archive/refs/heads/main.zip"
elif [[ "$1" == "-v" && -n "$2" ]]; then
    ZIP_URL="https://github.com/Liwyd/mirzaMIT/archive/refs/tags/$2.zip"
fi

    # Download and extract the repository
    TEMP_DIR="/tmp/mitbot"
    mkdir -p "$TEMP_DIR"
    wget -O "$TEMP_DIR/bot.zip" "$ZIP_URL" || {
        echo -e "\e[91mError: Failed to download the specified version.\033[0m"
        exit 1
    }

    unzip "$TEMP_DIR/bot.zip" -d "$TEMP_DIR"
    EXTRACTED_DIR=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d)
    mv "$EXTRACTED_DIR"/* "$BOT_DIR" || {
        echo -e "\e[91mError: Failed to move extracted files.\033[0m"
        exit 1
    }
    rm -rf "$TEMP_DIR"

    sudo chown -R www-data:www-data "$BOT_DIR"
    sudo chmod -R 755 "$BOT_DIR"

    echo -e "\n\033[33mMIT config and script have been installed successfully.\033[0m"


wait
if [ ! -d "/root/confmit" ]; then
    sudo mkdir /root/confmit || {
        echo -e "\e[91mError: Failed to create /root/confmit directory.\033[0m"
        exit 1
    }

    sleep 1

    touch /root/confmit/dbrootmit.txt || {
        echo -e "\e[91mError: Failed to create dbrootmit.txt.\033[0m"
        exit 1
    }
    sudo chmod -R 777 /root/confmit/dbrootmit.txt || {
        echo -e "\e[91mError: Failed to set permissions for dbrootmit.txt.\033[0m"
        exit 1
    }
    sleep 1

    randomdbpasstxt=$(openssl rand -base64 10 | tr -dc 'a-zA-Z0-9' | cut -c1-8)

    ASAS="$"

    echo "${ASAS}user = 'root';" >> /root/confmit/dbrootmit.txt
    echo "${ASAS}pass = '${randomdbpasstxt}';" >> /root/confmit/dbrootmit.txt
    echo "${ASAS}path = '${RANDOM_NUMBER}';" >> /root/confmit/dbrootmit.txt

    sleep 1

    passs=$(cat /root/confmit/dbrootmit.txt | grep '$pass' | cut -d"'" -f2)
    userrr=$(cat /root/confmit/dbrootmit.txt | grep '$user' | cut -d"'" -f2)

    sudo mysql -u $userrr -p$passs -e "alter user '$userrr'@'localhost' identified with mysql_native_password by '$passs';FLUSH PRIVILEGES;" || {
        echo -e "\e[91mError: Failed to alter MySQL user. Attempting recovery...\033[0m"

        # Enable skip-grant-tables at the end of the file
        sudo sed -i '$ a skip-grant-tables' /etc/mysql/mysql.conf.d/mysqld.cnf
        sudo systemctl restart mysql

        # Access MySQL to reset the root user
        sudo mysql <<EOF
DROP USER IF EXISTS 'root'@'localhost';
CREATE USER 'root'@'localhost' IDENTIFIED BY '${passs}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

        # Disable skip-grant-tables
        sudo sed -i '/skip-grant-tables/d' /etc/mysql/mysql.conf.d/mysqld.cnf
        sudo systemctl restart mysql

        # Retry MySQL login with the new credentials
        echo "SELECT 1" | mysql -u$userrr -p$passs 2>/dev/null || {
            echo -e "\e[91mError: Recovery failed. MySQL login still not working.\033[0m"
            exit 1
        }
    }

    echo "Folder created successfully!"
else
    echo "Folder already exists."
fi


clear

echo " "
echo -e "\e[32m SSL \033[0m\n"

read -p "Enter the domain: " domainname
while [[ ! "$domainname" =~ ^[a-zA-Z0-9.-]+$ ]]; do
    echo -e "\e[91mInvalid domain format. Please try again.\033[0m"
    read -p "Enter the domain: " domainname
done
    DOMAIN_NAME="$domainname"
    PATHS=$(cat /root/confmit/dbrootmit.txt | grep '$path' | cut -d"'" -f2)
    sudo ufw allow 80 || {
        echo -e "\e[91mError: Failed to allow port 80 in UFW.\033[0m"
        exit 1
    }
    sudo ufw allow 443 || {
        echo -e "\e[91mError: Failed to allow port 443 in UFW.\033[0m"
        exit 1
    }

    echo -e "\033[33mDisable apache2\033[0m"
    wait

    sudo systemctl stop apache2 || {
        echo -e "\e[91mError: Failed to stop Apache2.\033[0m"
        exit 1
    }
    sudo systemctl disable apache2 || {
        echo -e "\e[91mError: Failed to disable Apache2.\033[0m"
        exit 1
    }
    sudo apt install letsencrypt -y || {
        echo -e "\e[91mError: Failed to install letsencrypt.\033[0m"
        exit 1
    }
    sudo systemctl enable certbot.timer || {
        echo -e "\e[91mError: Failed to enable certbot timer.\033[0m"
        exit 1
    }
    sudo certbot certonly --standalone --agree-tos --preferred-challenges http -d $DOMAIN_NAME || {
        echo -e "\e[91mError: Failed to generate SSL certificate.\033[0m"
        exit 1
    }
    sudo apt install python3-certbot-apache -y || {
        echo -e "\e[91mError: Failed to install python3-certbot-apache.\033[0m"
        exit 1
    }
    sudo certbot --apache --agree-tos --preferred-challenges http -d $DOMAIN_NAME || {
        echo -e "\e[91mError: Failed to configure SSL with Certbot.\033[0m"
        exit 1
    }

    echo " "
    echo -e "\033[33mEnable apache2\033[0m"
    wait
    sudo systemctl enable apache2 || {
        echo -e "\e[91mError: Failed to enable Apache2.\033[0m"
        exit 1
    }
    sudo systemctl start apache2 || {
        echo -e "\e[91mError: Failed to start Apache2.\033[0m"
        exit 1
    }
            clear

        printf "\e[33m[+] \e[36mBot Token: \033[0m"
        read YOUR_BOT_TOKEN
        while [[ ! "$YOUR_BOT_TOKEN" =~ ^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$ ]]; do
            echo -e "\e[91mInvalid bot token format. Please try again.\033[0m"
            printf "\e[33m[+] \e[36mBot Token: \033[0m"
            read YOUR_BOT_TOKEN
        done

        printf "\e[33m[+] \e[36mChat id: \033[0m"
        read YOUR_CHAT_ID
        while [[ ! "$YOUR_CHAT_ID" =~ ^-?[0-9]+$ ]]; do
            echo -e "\e[91mInvalid chat ID format. Please try again.\033[0m"
            printf "\e[33m[+] \e[36mChat id: \033[0m"
            read YOUR_CHAT_ID
        done

        YOUR_DOMAIN="$DOMAIN_NAME"

    while true; do
        printf "\e[33m[+] \e[36musernamebot: \033[0m"
        read YOUR_BOTNAME
        if [ "$YOUR_BOTNAME" != "" ]; then
            break
        else
            echo -e "\e[91mError: Bot username cannot be empty. Please enter a valid username.\033[0m"
        fi
    done

    # Resolve bot username via Telegram getMe API
    echo -e "\033[33mResolving bot username from token...\033[0m"
    RESOLVED_USERNAME=$(curl -s "https://api.telegram.org/bot${YOUR_BOT_TOKEN}/getMe" | grep -oP '"username":"\K[^"]+')
    if [ -n "$RESOLVED_USERNAME" ]; then
        YOUR_BOTNAME="$RESOLVED_USERNAME"
        echo -e "\033[32mBot username resolved: @$YOUR_BOTNAME\033[0m"
    else
        echo -e "\033[33mCould not resolve bot username via API. Using provided username: $YOUR_BOTNAME\033[0m"
    fi

    MIT_SECRET=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9')

    ROOT_PASSWORD=$(cat /root/confmit/dbrootmit.txt | grep '$pass' | cut -d"'" -f2)
    ROOT_USER="root"
    echo "SELECT 1" | mysql -u$ROOT_USER -p$ROOT_PASSWORD 2>/dev/null || {
        echo -e "\e[91mError: MySQL connection failed.\033[0m"
        exit 1
    }

    if [ $? -eq 0 ]; then
        wait

        randomdbpass=$(openssl rand -base64 10 | tr -dc 'a-zA-Z0-9' | cut -c1-8)

        randomdbdb=$(openssl rand -base64 10 | tr -dc 'a-zA-Z' | cut -c1-8)

        if [[ $(mysql -u root -p$ROOT_PASSWORD -e "SHOW DATABASES LIKE 'mitbot${N}'") ]]; then
            clear
            echo -e "\n\e[91mYou have already created the database\033[0m\n"
        else
            dbname=mitbot${N}
            clear
            echo -e "\n\e[32mPlease enter the database username!\033[0m"
            printf "[+] Default user name is \e[91m${randomdbdb}\e[0m ( let it blank to use this user name ): "
            read dbuser
            if [ "$dbuser" = "" ]; then
                dbuser=$randomdbdb
            fi

            echo -e "\n\e[32mPlease enter the database password!\033[0m"
            printf "[+] Default password is \e[91m${randomdbpass}\e[0m ( let it blank to use this password ): "
            read dbpass
            if [ "$dbpass" = "" ]; then
                dbpass=$randomdbpass
            fi

            mysql -u root -p$ROOT_PASSWORD -e "CREATE DATABASE $dbname;" -e "CREATE USER '$dbuser'@'%' IDENTIFIED WITH mysql_native_password BY '$dbpass';GRANT ALL PRIVILEGES ON * . * TO '$dbuser'@'%';FLUSH PRIVILEGES;" -e "CREATE USER '$dbuser'@'localhost' IDENTIFIED WITH mysql_native_password BY '$dbpass';GRANT ALL PRIVILEGES ON * . * TO '$dbuser'@'localhost';FLUSH PRIVILEGES;" || {
                echo -e "\e[91mError: Failed to create database or user.\033[0m"
                exit 1
            }

            echo -e "\n\e[95mDatabase Created.\033[0m"

            clear



            ASAS="$"

            wait

            sleep 1

            file_path="/var/www/html/mitbot${N}/config.php"

            if [ -f "$file_path" ]; then
              rm "$file_path" || {
                echo -e "\e[91mError: Failed to delete old config.php.\033[0m"
                exit 1
              }
              echo -e "File deleted successfully."
            else
              echo -e "File not found."
            fi

            sleep 1

            secrettoken=$(openssl rand -base64 10 | tr -dc 'a-zA-Z0-9' | cut -c1-8)

            echo -e "<?php" >> /var/www/html/mitbot${N}/config.php
            echo -e "define('MIT_SECRET_CODE', '${MIT_SECRET}');" >> /var/www/html/mitbot${N}/config.php
            echo -e "${ASAS}APIKEY = '${YOUR_BOT_TOKEN}';" >> /var/www/html/mitbot${N}/config.php
            echo -e "${ASAS}usernamedb = '${dbuser}';" >> /var/www/html/mitbot${N}/config.php
            echo -e "${ASAS}passworddb = '${dbpass}';" >> /var/www/html/mitbot${N}/config.php
            echo -e "${ASAS}dbname = '${dbname}';" >> /var/www/html/mitbot${N}/config.php
            echo -e "${ASAS}domainhosts = '${YOUR_DOMAIN}/mitbot${N}';" >> /var/www/html/mitbot${N}/config.php
            echo -e "${ASAS}adminnumber = '${YOUR_CHAT_ID}';" >> /var/www/html/mitbot${N}/config.php
            echo -e "${ASAS}usernamebot = '${YOUR_BOTNAME}';" >> /var/www/html/mitbot${N}/config.php
            echo -e "${ASAS}secrettoken = '${secrettoken}';" >> /var/www/html/mitbot${N}/config.php
            echo -e "${ASAS}connect = mysqli_connect('localhost', \$usernamedb, \$passworddb, \$dbname);" >> /var/www/html/mitbot${N}/config.php
            echo -e "if (${ASAS}connect->connect_error) {" >> /var/www/html/mitbot${N}/config.php
            echo -e "die(' The connection to the database failed:' . ${ASAS}connect->connect_error);" >> /var/www/html/mitbot${N}/config.php
            echo -e "}" >> /var/www/html/mitbot${N}/config.php
            echo -e "mysqli_set_charset(${ASAS}connect, 'utf8mb4');" >> /var/www/html/mitbot${N}/config.php
            text_to_save=$(cat <<EOF
\$options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES   => false,
];
\$dsn = "mysql:host=localhost;dbname=${ASAS}dbname;charset=utf8mb4";
try {
     \$pdo = new PDO(\$dsn, \$usernamedb, \$passworddb, \$options);
} catch (\PDOException \$e) {
     throw new \PDOException(\$e->getMessage(), (int)\$e->getCode());
}
EOF
)
echo -e "$text_to_save" >> /var/www/html/mitbot${N}/config.php
            echo -e "?>" >> /var/www/html/mitbot${N}/config.php

            sleep 1

            curl -F "url=https://${YOUR_DOMAIN}/mitbot${N}/index.php" \
     -F "secret_token=${secrettoken}" \
     "https://api.telegram.org/bot${YOUR_BOT_TOKEN}/setWebhook" || {
                echo -e "\e[91mError: Failed to set webhook for bot.\033[0m"
                exit 1
            }
            MESSAGE="✅ The bot is installed! for start the bot send /start command."
            curl -s -X POST "https://api.telegram.org/bot${YOUR_BOT_TOKEN}/sendMessage" -d chat_id="${YOUR_CHAT_ID}" -d text="$MESSAGE" || {
                echo -e "\e[91mError: Failed to send message to Telegram.\033[0m"
                exit 1
            }

            sleep 1
            sudo systemctl start apache2 || {
                echo -e "\e[91mError: Failed to start Apache2.\033[0m"
                exit 1
            }
            url="https://${YOUR_DOMAIN}/mitbot${N}/table.php"
            curl $url || {
                echo -e "\e[91mError: Failed to fetch URL from domain.\033[0m"
                exit 1
            }

            clear

            echo " "

            echo -e "\e[102mDomain Bot: https://${YOUR_DOMAIN}\033[0m"
            echo -e "\e[104mDatabase address: https://${YOUR_DOMAIN}/phpmyadmin\033[0m"
            echo -e "\e[33mDatabase name: \e[36m${dbname}\033[0m"
            echo -e "\e[33mDatabase username: \e[36m${dbuser}\033[0m"
            echo -e "\e[33mDatabase password: \e[36m${dbpass}\033[0m"
            echo " "
            echo -e "MIT VPN Bot"
        fi


    elif [ "$ROOT_PASSWORD" = "" ] || [ "$ROOT_USER" = "" ]; then
        echo -e "\n\e[36mThe password is empty.\033[0m\n"
    else

        echo -e "\n\e[36mThe password is not correct.\033[0m\n"

    fi

    # Add executable permission and link
    chmod +x /root/install.sh
    ln -vs /root/install.sh /usr/local/bin/mit

}

function install_bot_with_marzban() {
    # Display warning and confirmation
    echo -e "\033[41m[IMPORTANT WARNING]\033[0m \033[1;33mMarzban panel is detected on your server. Please make sure to backup the Marzban database before installing MIT VPN Bot.\033[0m"
    read -p "Are you sure you want to install MIT VPN Bot alongside Marzban? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "\e[91mInstallation aborted by user.\033[0m"
        exit 0
    fi

    # Check database type
    echo -e "\e[32mChecking Marzban database type...\033[0m"
    DB_TYPE=$(detect_database_type)
    if [ "$DB_TYPE" != "mysql" ]; then
        echo -e "\e[91mError: Your database is $DB_TYPE. To install MIT VPN Bot, you must use MySQL.\033[0m"
        echo -e "\e[93mPlease configure Marzban to use MySQL and try again.\033[0m"
        exit 1
    fi
    echo -e "\e[92mMySQL detected. Proceeding with installation...\033[0m"

    # Check if port 80 is free before proceeding
    echo -e "\e[32mChecking port availability...\033[0m"
    if sudo ss -tuln | grep -q ":80 "; then
        echo -e "\e[91mError: Port 80 is already in use. Please free port 80 and run the script again.\033[0m"
        exit 1
    fi
    if sudo ss -tuln | grep -q ":88 "; then
        echo -e "\e[91mError: Port 88 is already in use. Please free port 88 and run the script again.\033[0m"
        exit 1
    fi
    echo -e "\e[92mPorts 80 and 88 are free. Proceeding with installation...\033[0m"

    # Try normal update/upgrade first
    if ! (sudo apt update && sudo apt upgrade -y); then
        echo -e "\e[93mUpdate/upgrade failed. Attempting to fix using alternative mirrors...\033[0m"
        if fix_update_issues; then
            # Try update/upgrade again after fixing mirrors
            if sudo apt update && sudo apt upgrade -y; then
                echo -e "\e[92mSystem updated successfully after fixing mirrors...\033[0m\n"
            else
                echo -e "\e[91mError: Failed to update even after trying alternative mirrors.\033[0m"
                exit 1
            fi
        else
            echo -e "\e[91mError: Failed to update/upgrade system and mirror fix failed.\033[0m"
            exit 1
        fi
    else
        echo -e "\e[92mSystem updated successfully...\033[0m\n"
    fi

    sudo apt-get install software-properties-common || {
        echo -e "\e[91mError: Failed to install software-properties-common.\033[0m"
        exit 1
    }

    # Install MySQL client if not already installed
    echo -e "\e[32mChecking and installing MySQL client...\033[0m"
    if ! command -v mysql &>/dev/null; then
        sudo apt install -y mysql-client || {
            echo -e "\e[91mError: Failed to install MySQL client. Please install it manually and try again.\033[0m"
            exit 1
        }
        echo -e "\e[92mMySQL client installed successfully.\033[0m"
    else
        echo -e "\e[92mMySQL client is already installed.\033[0m"
    fi

    # Add Ondřej Surý PPA for PHP 8.2
    sudo apt install -y software-properties-common || {
        echo -e "\e[91mError: Failed to install software-properties-common.\033[0m"
        exit 1
    }
    sudo add-apt-repository -y ppa:ondrej/php || {
        echo -e "\e[91mError: Failed to add PPA ondrej/php. Trying with locale override...\033[0m"
        sudo LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php || {
            echo -e "\e[91mError: Failed to add PPA even with locale override.\033[0m"
            exit 1
        }
    }
    sudo apt update || {
        echo -e "\e[91mError: Failed to update package list after adding PPA.\033[0m"
        exit 1
    }

    # Install all required packages
    sudo apt install -y git unzip curl wget jq || {
        echo -e "\e[91mError: Failed to install basic tools.\033[0m"
        exit 1
    }

    # Install Apache if not installed
    if ! dpkg -s apache2 &>/dev/null; then
        sudo apt install -y apache2 || {
            echo -e "\e[91mError: Failed to install Apache2.\033[0m"
            exit 1
        }
    fi

    # Install PHP 8.2 and all necessary modules (including PDO)
    DEBIAN_FRONTEND=noninteractive sudo apt install -y php8.2 php8.2-fpm php8.2-mysql php8.2-mbstring php8.2-zip php8.2-gd php8.2-curl php8.2-soap php8.2-ssh2 libssh2-1-dev libssh2-1 php8.2-pdo || {
        echo -e "\e[91mError: Failed to install PHP 8.2 and modules.\033[0m"
        exit 1
    }

    # Install additional Apache module
    sudo apt install -y libapache2-mod-php8.2 || {
        echo -e "\e[91mError: Failed to install libapache2-mod-php8.2.\033[0m"
        exit 1
    }

    sudo apt install -y python3-certbot-apache || {
        echo -e "\e[91mError: Failed to install Certbot for Apache.\033[0m"
        exit 1
    }
    sudo systemctl enable certbot.timer || {
        echo -e "\e[91mError: Failed to enable certbot timer.\033[0m"
        exit 1
    }

    # Install UFW if not present
    if ! dpkg -s ufw &>/dev/null; then
        sudo apt install -y ufw || {
            echo -e "\e[91mError: Failed to install UFW.\033[0m"
            exit 1
        }
    fi

    # Check Marzban and use its MySQL (Docker-based)
    ENV_FILE="/opt/marzban/.env"
    if [ ! -f "$ENV_FILE" ]; then
        echo -e "\e[91mError: Marzban .env file not found. Cannot proceed without Marzban configuration.\033[0m"
        exit 1
    fi

    # Get MySQL root password from .env
    MYSQL_ROOT_PASSWORD=$(grep "MYSQL_ROOT_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2 | tr -d '[:space:]' | sed 's/"//g')
    ROOT_USER="root"

    # Check if MYSQL_ROOT_PASSWORD is empty or invalid
    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        echo -e "\e[93mWarning: Could not retrieve MySQL root password from Marzban .env file.\033[0m"
        read -s -p "Please enter the MySQL root password manually: " MYSQL_ROOT_PASSWORD
        echo
    fi

    # Dynamically find the MySQL container
    MYSQL_CONTAINER=$(docker ps -q --filter "name=mysql" --no-trunc)
    if [ -z "$MYSQL_CONTAINER" ]; then
        echo -e "\e[91mError: Could not find a running MySQL container. Ensure Marzban is running with Docker.\033[0m"
        echo -e "\e[93mRunning containers:\033[0m"
        docker ps
        exit 1
    fi

    echo "Testing MySQL connection..."

    # Read MySQL root password from .env
    if [ -f "/opt/marzban/.env" ]; then
        MYSQL_ROOT_PASSWORD=$(grep -E '^MYSQL_ROOT_PASSWORD=' /opt/marzban/.env | cut -d '=' -f2- | tr -d '" \n\r')
        if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
            echo -e "\e[93mWarning: MYSQL_ROOT_PASSWORD not found in .env. Please enter it manually.\033[0m"
            read -s -p "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
            echo
        fi
    else
        echo -e "\e[93mWarning: .env file not found. Please enter MySQL root password manually.\033[0m"
        read -s -p "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
        echo
    fi

    ROOT_USER="root"
    echo -e "\e[32mUsing MySQL container: $(docker inspect -f '{{.Name}}' "$MYSQL_CONTAINER" | cut -c2-)\033[0m"

    # Try connecting directly to host first (for mysql:latest with network_mode: host)
    mysql -u "$ROOT_USER" -p"$MYSQL_ROOT_PASSWORD" -h 127.0.0.1 -P 3306 -e "SELECT 1;" 2>/tmp/mysql_error.log
    if [ $? -eq 0 ]; then
        echo -e "\e[92mMySQL connection successful (direct host method).\033[0m"
    else
        # If direct connection fails, try inside container (for mysql:lts)
        if [ -n "$MYSQL_CONTAINER" ]; then
            echo -e "\e[93mDirect connection failed, trying inside container...\033[0m"
            docker exec "$MYSQL_CONTAINER" bash -c "echo 'SELECT 1;' | mysql -u '$ROOT_USER' -p'$MYSQL_ROOT_PASSWORD'" 2>/tmp/mysql_error.log
            if [ $? -eq 0 ]; then
                echo -e "\e[92mMySQL connection successful (container method).\033[0m"
            else
                echo -e "\e[91mError: Failed to connect to MySQL using both methods.\033[0m"
                echo -e "\e[93mPassword used: '$MYSQL_ROOT_PASSWORD'\033[0m"
                echo -e "\e[93mError details:\033[0m"
                cat /tmp/mysql_error.log
                echo -e "\e[93mPlease ensure MySQL is running and the root password is correct.\033[0m"
                read -s -p "Enter the correct MySQL root password: " NEW_PASSWORD
                echo
                MYSQL_ROOT_PASSWORD="$NEW_PASSWORD"
                # Retry with new password (direct method first)
                mysql -u "$ROOT_USER" -p"$MYSQL_ROOT_PASSWORD" -h 127.0.0.1 -P 3306 -e "SELECT 1;" 2>/tmp/mysql_error.log || {
                    docker exec "$MYSQL_CONTAINER" bash -c "echo 'SELECT 1;' | mysql -u '$ROOT_USER' -p'$MYSQL_ROOT_PASSWORD'" 2>/tmp/mysql_error.log || {
                        echo -e "\e[91mError: Still can't connect with new password.\033[0m"
                        echo -e "\e[93mError details:\033[0m"
                        cat /tmp/mysql_error.log
                        exit 1
                    }
                }
                echo -e "\e[92mMySQL connection successful with new password.\033[0m"
            fi
        else
            echo -e "\e[91mError: No MySQL container found and direct connection failed.\033[0m"
            echo -e "\e[93mPassword used: '$MYSQL_ROOT_PASSWORD'\033[0m"
            echo -e "\e[93mError details:\033[0m"
            cat /tmp/mysql_error.log
            exit 1
        fi
    fi

    # Ask for database username and password like Marzban
    clear
    echo -e "\e[33mConfiguring MIT VPN Bot database credentials...\033[0m"
    default_dbuser=$(openssl rand -base64 12 | tr -dc 'a-zA-Z' | head -c8)
    printf "\e[33m[+] \e[36mDatabase username (default: $default_dbuser): \033[0m"
    read dbuser
    if [ -z "$dbuser" ]; then
        dbuser="$default_dbuser"
    fi

    default_dbpass=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c12)
    printf "\e[33m[+] \e[36mDatabase password (default: $default_dbpass): \033[0m"
    read -s dbpass
    echo
    if [ -z "$dbpass" ]; then
        dbpass="$default_dbpass"
    fi
    dbname="mitbot${N}"

    # Create database and user inside Docker container
    docker exec "$MYSQL_CONTAINER" bash -c "mysql -u '$ROOT_USER' -p'$MYSQL_ROOT_PASSWORD' -e \"CREATE DATABASE IF NOT EXISTS $dbname; CREATE USER IF NOT EXISTS '$dbuser'@'%' IDENTIFIED BY '$dbpass'; GRANT ALL PRIVILEGES ON $dbname.* TO '$dbuser'@'%'; FLUSH PRIVILEGES;\"" || {
        echo -e "\e[91mError: Failed to create database or user in Marzban MySQL container.\033[0m"
        exit 1
    }
    echo -e "\e[92mDatabase '$dbname' created successfully.\033[0m"

    # Bot directory setup
    if [ -d "$BOT_DIR" ]; then
        echo -e "\e[93mDirectory $BOT_DIR already exists. Removing...\033[0m"
        sudo rm -rf "$BOT_DIR" || {
            echo -e "\e[91mError: Failed to remove existing directory $BOT_DIR.\033[0m"
            exit 1
        }
    fi
    sudo mkdir -p "$BOT_DIR" || {
        echo -e "\e[91mError: Failed to create directory $BOT_DIR.\033[0m"
        exit 1
    }

    # Download bot files
    ZIP_URL=$(curl -s https://api.github.com/repos/Liwyd/mirzaMIT/releases/latest | grep "zipball_url" | cut -d '"' -f 4)
    if [[ "$1" == "-v" && "$2" == "beta" ]] || [[ "$1" == "-beta" ]] || [[ "$1" == "-" && "$2" == "beta" ]]; then
        ZIP_URL="https://github.com/Liwyd/mirzaMIT/archive/refs/heads/main.zip"
    elif [[ "$1" == "-v" && -n "$2" ]]; then
        ZIP_URL="https://github.com/Liwyd/mirzaMIT/archive/refs/tags/$2.zip"
    fi

    TEMP_DIR="/tmp/mitbot"
    mkdir -p "$TEMP_DIR"
    wget -O "$TEMP_DIR/bot.zip" "$ZIP_URL" || {
        echo -e "\e[91mError: Failed to download bot files.\033[0m"
        exit 1
    }
    unzip "$TEMP_DIR/bot.zip" -d "$TEMP_DIR" || {
        echo -e "\e[91mError: Failed to unzip bot files.\033[0m"
        exit 1
    }
    EXTRACTED_DIR=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d)
    mv "$EXTRACTED_DIR"/* "$BOT_DIR" || {
        echo -e "\e[91mError: Failed to move bot files.\033[0m"
        exit 1
    }
    rm -rf "$TEMP_DIR"

    sudo chown -R www-data:www-data "$BOT_DIR"
    sudo chmod -R 755 "$BOT_DIR"
    echo -e "\e[92mBot files installed in $BOT_DIR.\033[0m"
    sleep 3
    clear

    # Configure Apache to use port 80 temporarily and 88 for HTTPS
    echo -e "\e[32mConfiguring Apache ports...\033[0m"
    sudo bash -c "echo -n > /etc/apache2/ports.conf"  # Clear the file
    cat <<EOF | sudo tee /etc/apache2/ports.conf
# If you just change the port or add more ports here, you will likely also
# have to change the VirtualHost statement in
# /etc/apache2/sites-enabled/000-default.conf

Listen 80
Listen 88

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet
EOF
    if [ $? -ne 0 ]; then
        echo -e "\e[91mError: Failed to configure ports.conf.\033[0m"
        exit 1
    fi

    # Clear and configure VirtualHost for port 80
    sudo bash -c "echo -n > /etc/apache2/sites-available/000-default.conf"  # Clear the file
    cat <<EOF | sudo tee /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet
EOF
    if [ $? -ne 0 ]; then
        echo -e "\e[91mError: Failed to configure 000-default.conf.\033[0m"
        exit 1
    fi

    # Enable Apache and apply port changes
    sudo systemctl enable apache2 || {
        echo -e "\e[91mError: Failed to enable Apache2.\033[0m"
        exit 1
    }
    sudo systemctl restart apache2 || {
        echo -e "\e[91mError: Failed to restart Apache2.\033[0m"
        exit 1
    }

    # SSL setup on port 88
    echo -e "\e[32mConfiguring SSL on port 88...\033[0m\n"
    sudo ufw allow 80 || {
        echo -e "\e[91mError: Failed to configure firewall for port 80.\033[0m"
        exit 1
    }
    sudo ufw allow 88 || {
        echo -e "\e[91mError: Failed to configure firewall for port 88.\033[0m"
        exit 1
    }
    clear
    printf "\e[33m[+] \e[36mEnter the domain (e.g., example.com): \033[0m"
    read domainname
    while [[ ! "$domainname" =~ ^[a-zA-Z0-9.-]+$ ]]; do
        echo -e "\e[91mInvalid domain format. Must be like 'example.com'. Please try again.\033[0m"
        printf "\e[33m[+] \e[36mEnter the domain (e.g., example.com): \033[0m"
        read domainname
    done
    DOMAIN_NAME="$domainname"
    echo -e "\e[92mDomain set to: $DOMAIN_NAME\033[0m"

    sudo systemctl restart apache2 || {
        echo -e "\e[91mError: Failed to restart Apache2 before Certbot.\033[0m"
        exit 1
    }
    sudo certbot --apache --agree-tos --preferred-challenges http -d "$DOMAIN_NAME" --https-port 88 --no-redirect || {
        echo -e "\e[91mError: Failed to configure SSL with Certbot on port 88.\033[0m"
        exit 1
    }

    # Ensure SSL VirtualHost uses port 88 with correct settings
    sudo bash -c "echo -n > /etc/apache2/sites-available/000-default-le-ssl.conf"  # Clear any existing file
    cat <<EOF | sudo tee /etc/apache2/sites-available/000-default-le-ssl.conf
<IfModule mod_ssl.c>
<VirtualHost *:88>
    ServerAdmin webmaster@localhost
    ServerName $DOMAIN_NAME
    DocumentRoot /var/www/html
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem
    SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite HIGH:!aNULL:!MD5
</VirtualHost>
</IfModule>
EOF
    if [ $? -ne 0 ]; then
        echo -e "\e[91mError: Failed to create SSL VirtualHost configuration.\033[0m"
        exit 1
    fi
    sudo a2enmod ssl || {
        echo -e "\e[91mError: Failed to enable SSL module.\033[0m"
        exit 1
    }
    sudo a2ensite 000-default-le-ssl.conf || {
        echo -e "\e[91mError: Failed to enable SSL site.\033[0m"
        exit 1
    }
    # Force ports.conf to only listen on 88 before restarting Apache
    sudo bash -c "echo -n > /etc/apache2/ports.conf"
    cat <<EOF | sudo tee /etc/apache2/ports.conf
Listen 88
EOF
    sudo apache2ctl configtest || {
        echo -e "\e[91mError: Apache configuration test failed after Certbot.\033[0m"
        exit 1
    }
    sudo systemctl restart apache2 || {
        echo -e "\e[91mError: Failed to restart Apache2 after SSL configuration.\033[0m"
        systemctl status apache2.service
        exit 1
    }

    # Disable port 80 after SSL is configured
    echo -e "\e[32mDisabling port 80 as it's no longer needed...\033[0m"
    # Ports.conf already set to Listen 88 in previous step, just verify
    sudo a2dissite 000-default.conf || {
        echo -e "\e[91mError: Failed to disable port 80 VirtualHost.\033[0m"
        exit 1
    }
    sudo ufw delete allow 80 || {
        echo -e "\e[91mError: Failed to remove port 80 from firewall.\033[0m"
        exit 1
    }
    sudo apache2ctl configtest || {
        echo -e "\e[91mError: Apache configuration test failed.\033[0m"
        exit 1
    }
    sudo systemctl restart apache2 || {
        echo -e "\e[91mError: Failed to restart Apache2 after disabling port 80.\033[0m"
        systemctl status apache2.service
        exit 1
    }
    echo -e "\e[92mSSL configured successfully on port 88. Port 80 disabled.\033[0m"
    sleep 3
    clear

    # Bot token, chat ID, and username
    printf "\e[33m[+] \e[36mBot Token: \033[0m"
    read YOUR_BOT_TOKEN
    while [[ ! "$YOUR_BOT_TOKEN" =~ ^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$ ]]; do
        echo -e "\e[91mInvalid bot token format. Please try again.\033[0m"
        printf "\e[33m[+] \e[36mBot Token: \033[0m"
        read YOUR_BOT_TOKEN
    done

    printf "\e[33m[+] \e[36mChat id: \033[0m"
    read YOUR_CHAT_ID
    while [[ ! "$YOUR_CHAT_ID" =~ ^-?[0-9]+$ ]]; do
        echo -e "\e[91mInvalid chat ID format. Please try again.\033[0m"
        printf "\e[33m[+] \e[36mChat id: \033[0m"
        read YOUR_CHAT_ID
    done

    YOUR_DOMAIN="$DOMAIN_NAME:88"  # Use port 88 for HTTPS
    printf "\e[33m[+] \e[36mUsernamebot: \033[0m"
    read YOUR_BOTNAME
    while [ -z "$YOUR_BOTNAME" ]; do
        echo -e "\e[91mError: Bot username cannot be empty.\033[0m"
        printf "\e[33m[+] \e[36mUsernamebot: \033[0m"
        read YOUR_BOTNAME
    done

    # Resolve bot username via Telegram getMe API
    echo -e "\033[33mResolving bot username from token...\033[0m"
    RESOLVED_USERNAME=$(curl -s "https://api.telegram.org/bot${YOUR_BOT_TOKEN}/getMe" | grep -oP '"username":"\K[^"]+')
    if [ -n "$RESOLVED_USERNAME" ]; then
        YOUR_BOTNAME="$RESOLVED_USERNAME"
        echo -e "\033[32mBot username resolved: @$YOUR_BOTNAME\033[0m"
    else
        echo -e "\033[33mCould not resolve bot username via API. Using provided username: $YOUR_BOTNAME\033[0m"
    fi

    MIT_SECRET=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9')

    # Create config file with correct MySQL host and PDO
    ASAS="$"
    secrettoken=$(openssl rand -base64 10 | tr -dc 'a-zA-Z0-9' | cut -c1-8)
    cat <<EOF > "$BOT_DIR/config.php"
<?php
define('MIT_SECRET_CODE', '${MIT_SECRET}');
${ASAS}APIKEY = '$YOUR_BOT_TOKEN';
${ASAS}usernamedb = '$dbuser';
${ASAS}passworddb = '$dbpass';
${ASAS}dbname = '$dbname';
${ASAS}domainhosts = '$YOUR_DOMAIN/mitbot${N}';
${ASAS}adminnumber = '$YOUR_CHAT_ID';
${ASAS}usernamebot = '$YOUR_BOTNAME';
${ASAS}secrettoken = '$secrettoken';

${ASAS}connect = mysqli_connect('127.0.0.1', \$usernamedb, \$passworddb, \$dbname);
if (${ASAS}connect->connect_error) {
    die('Database connection failed: ' . ${ASAS}connect->connect_error);
}
mysqli_set_charset(${ASAS}connect, 'utf8mb4');

${ASAS}options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES   => false,
];
${ASAS}dsn = "mysql:host=127.0.0.1;port=3306;dbname=\$dbname;charset=utf8mb4";
try {
    ${ASAS}pdo = new PDO(\$dsn, \$usernamedb, \$passworddb, \$options);
} catch (\PDOException \$e) {
    die('PDO Connection failed: ' . \$e->getMessage());
}
?>
EOF

    # Set webhook with port 88
    curl -F "url=https://${YOUR_DOMAIN}/mitbot${N}/index.php" \
         -F "secret_token=${secrettoken}" \
         "https://api.telegram.org/bot${YOUR_BOT_TOKEN}/setWebhook" || {
        echo -e "\e[91mError: Failed to set webhook.\033[0m"
        exit 1
    }

    # Send confirmation message
    MESSAGE="✅ The bot is installed! for start bot send comment /start"
    curl -s -X POST "https://api.telegram.org/bot${YOUR_BOT_TOKEN}/sendMessage" -d chat_id="${YOUR_CHAT_ID}" -d text="$MESSAGE" || {
        echo -e "\033[31mError: Failed to send message to Telegram.\033[0m"
        return 1
    }

    # Execute table creation script
    TABLE_SETUP_URL="https://${YOUR_DOMAIN}/mitbot${N}/table.php"
    echo -e "\033[33mSetting up database tables...\033[0m"
    curl $TABLE_SETUP_URL || {
        echo -e "\033[31mError: Failed to execute table creation script at $TABLE_SETUP_URL.\033[0m"
        return 1
    }

    # Output Bot Information
    echo -e "\033[32mBot installed successfully!\033[0m"
    echo -e "\033[102mDomain Bot: https://$DOMAIN_NAME\033[0m"
    echo -e "\033[104mDatabase address: https://$DOMAIN_NAME/phpmyadmin\033[0m"
    echo -e "\033[33mDatabase name: \033[36m$DB_NAME\033[0m"
    echo -e "\033[33mDatabase username: \033[36m$DB_USERNAME\033[0m"
    echo -e "\033[33mDatabase password: \033[36m$DB_PASSWORD\033[0m"

    # Add executable permission and link
    chmod +x /root/install.sh
    ln -vs /root/install.sh /usr/local/bin/mit
}

# Update Function
function update_bot() {
    echo "Updating MIT VPN Bot..."

    # Update server packages
    if ! sudo apt update && sudo apt upgrade -y; then
        echo -e "\e[91mError updating the server. Exiting...\033[0m"
        exit 1
    fi
    echo -e "\e[92mServer packages updated successfully...\033[0m\n"

    # Detect all bot instances
    local instances=()
    for cfg in /var/www/html/mitbot*/config.php; do
        if [ -f "$cfg" ]; then
            local dir=$(dirname "$cfg")
            instances+=("$dir")
        fi
    done

    if [ ${#instances[@]} -eq 0 ]; then
        echo -e "\e[91mError: No MIT VPN Bot instances found. Please install one first.\033[0m"
        exit 1
    fi

    # Select instance to update
    local SELECTED_DIR=""
    if [ ${#instances[@]} -eq 1 ]; then
        SELECTED_DIR="${instances[0]}"
        echo -e "\e[92mFound bot instance: $(basename "$SELECTED_DIR")\033[0m"
    else
        echo -e "\e[36mMultiple bot instances found:\033[0m"
        for i in "${!instances[@]}"; do
            echo -e "\e[33m$((i+1)))\033[0m $(basename "${instances[$i]}")"
        done
        echo ""
        read -p "Select instance to update [1-${#instances[@]}]: " choice
        if [[ "$choice" -ge 1 && "$choice" -le ${#instances[@]} ]]; then
            SELECTED_DIR="${instances[$((choice-1))]}"
        else
            echo -e "\e[91mInvalid selection. Exiting...\033[0m"
            exit 1
        fi
    fi

    BOT_DIR="$SELECTED_DIR"

    # Fetch latest release from GitHub
    # Check for version flag
    if [[ "$1" == "-beta" ]] || [[ "$1" == "-v" && "$2" == "beta" ]]; then
        ZIP_URL="https://github.com/Liwyd/mirzaMIT/archive/refs/heads/main.zip"
    else
        ZIP_URL=$(curl -s https://api.github.com/repos/Liwyd/mirzaMIT/releases/latest | grep "zipball_url" | cut -d '"' -f4)
    fi

    # Create temporary directory
    TEMP_DIR="/tmp/mitbot_update"
    mkdir -p "$TEMP_DIR"

    # Download and extract
    wget -O "$TEMP_DIR/bot.zip" "$ZIP_URL" || {
        echo -e "\e[91mError: Failed to download update package.\033[0m"
        exit 1
    }
    unzip "$TEMP_DIR/bot.zip" -d "$TEMP_DIR"

    # Find extracted directory
    EXTRACTED_DIR=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d)

    # Backup config file
    CONFIG_PATH="${BOT_DIR}/config.php"
    TEMP_CONFIG="/root/mit_config_backup.php"
    if [ -f "$CONFIG_PATH" ]; then
        cp "$CONFIG_PATH" "$TEMP_CONFIG" || {
            echo -e "\e[91mConfig file backup failed!\033[0m"
            exit 1
        }
    fi

    # Remove old version
    sudo rm -rf "$BOT_DIR" || {
        echo -e "\e[91mFailed to remove old bot files!\033[0m"
        exit 1
    }

    # Move new files
    sudo mkdir -p "$BOT_DIR"
    sudo mv "$EXTRACTED_DIR"/* "$BOT_DIR/" || {
        echo -e "\e[91mFile transfer failed!\033[0m"
        exit 1
    }

    # Restore config file
    if [ -f "$TEMP_CONFIG" ]; then
        sudo mv "$TEMP_CONFIG" "$CONFIG_PATH" || {
            echo -e "\e[91mConfig file restore failed!\033[0m"
            exit 1
        }
    fi

    # Copy the new install.sh to /root/
    if [ -f "${BOT_DIR}/install.sh" ]; then
        sudo cp "${BOT_DIR}/install.sh" /root/install.sh
        echo -e "\n\e[92mCopied latest install.sh to /root/install.sh.\033[0m"
    else
        echo -e "\n\e[91mWarning: install.sh not found in ${BOT_DIR}/ after update. Cannot update /root/install.sh.\033[0m"
    fi

    # Set permissions
    sudo chown -R www-data:www-data "$BOT_DIR/"
    sudo chmod -R 755 "$BOT_DIR/"

    # Run setup script
    URL=$(grep '\$domainhosts' "$CONFIG_PATH" | cut -d"'" -f2)
    curl -s "https://$URL/table.php" || {
        echo -e "\e[91mSetup script execution failed!\033[0m"
    }

    # Cleanup
    rm -rf "$TEMP_DIR"

    echo -e "\n\e[92mMIT VPN Bot ($(basename "$BOT_DIR")) updated to latest version successfully!\033[0m"

    # Ensure /root/install.sh is executable and linked
    if [ -f "/root/install.sh" ]; then
        sudo chmod +x /root/install.sh
        sudo ln -vsf /root/install.sh /usr/local/bin/mit
        echo -e "\e[92mEnsured /root/install.sh is executable and 'mit' command is linked.\033[0m"
    else
        echo -e "\e[91mError: /root/install.sh not found after update attempt. Cannot make it executable or link 'mit' command.\033[0m"
    fi
}

# Delete Function
function remove_bot() {
    echo -e "\e[33mStarting MIT VPN Bot removal process...\033[0m"
    LOG_FILE="/var/log/remove_bot.log"
    echo "Log file: $LOG_FILE" > "$LOG_FILE"

    # Detect all bot instances
    local instances=()
    for cfg in /var/www/html/mitbot*/config.php; do
        if [ -f "$cfg" ]; then
            local dir=$(dirname "$cfg")
            instances+=("$dir")
        fi
    done

    if [ ${#instances[@]} -eq 0 ]; then
        echo -e "\e[31m[ERROR]\033[0m No MIT VPN Bot instances found." | tee -a "$LOG_FILE"
        echo -e "\e[33mNothing to remove. Exiting...\033[0m" | tee -a "$LOG_FILE"
        sleep 2
        exit 1
    fi

    # Select instance to remove
    local SELECTED_DIR=""
    if [ ${#instances[@]} -eq 1 ]; then
        SELECTED_DIR="${instances[0]}"
        echo -e "\e[92mFound bot instance: $(basename "$SELECTED_DIR")\033[0m" | tee -a "$LOG_FILE"
    else
        echo -e "\e[36mMultiple bot instances found:\033[0m" | tee -a "$LOG_FILE"
        for i in "${!instances[@]}"; do
            echo -e "\e[33m$((i+1)))\033[0m $(basename "${instances[$i]}")" | tee -a "$LOG_FILE"
        done
        echo ""
        read -p "Select instance to remove [1-${#instances[@]}]: " choice
        if [[ "$choice" -ge 1 && "$choice" -le ${#instances[@]} ]]; then
            SELECTED_DIR="${instances[$((choice-1))]}"
        else
            echo -e "\e[91mInvalid selection. Exiting...\033[0m" | tee -a "$LOG_FILE"
            exit 1
        fi
    fi

    BOT_DIR="$SELECTED_DIR"

    # User Confirmation
    read -p "Are you sure you want to remove $(basename "$BOT_DIR") and its dependencies? (y/n): " choice
    if [[ "$choice" != "y" ]]; then
        echo "Aborting..." | tee -a "$LOG_FILE"
        exit 0
    fi

    # Check if Marzban is installed and redirect to appropriate function
    if check_marzban_installed; then
        echo -e "\e[41m[IMPORTANT NOTICE]\033[0m \e[33mMarzban detected. Proceeding with Marzban-compatible removal.\033[0m" | tee -a "$LOG_FILE"
        remove_bot_with_marzban
        return 0
    fi

    # Proceed with normal removal if Marzban is not installed
    echo "Removing MIT VPN Bot ($(basename "$BOT_DIR"))..." | tee -a "$LOG_FILE"

    # Get database name from config before removing
    local CONFIG_PATH="${BOT_DIR}/config.php"
    local DB_NAME=""
    if [ -f "$CONFIG_PATH" ]; then
        DB_NAME=$(grep '^\$dbname' "$CONFIG_PATH" | awk -F"'" '{print $2}')
    fi

    # Delete the Bot Directory
    if [ -d "$BOT_DIR" ]; then
        sudo rm -rf "$BOT_DIR" && echo -e "\e[92mBot directory removed: $BOT_DIR\033[0m" | tee -a "$LOG_FILE" || {
            echo -e "\e[91mFailed to remove bot directory: $BOT_DIR. Exiting...\033[0m" | tee -a "$LOG_FILE"
            exit 1
        }
    fi

    # Drop the specific database
    if [ -n "$DB_NAME" ]; then
        ROOT_PASSWORD=$(cat /root/confmit/dbrootmit.txt | grep '$pass' | cut -d"'" -f2)
        ROOT_USER="root"
        mysql -u "$ROOT_USER" -p"$ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" 2>/dev/null && {
            echo -e "\e[92mDatabase $DB_NAME removed.\033[0m" | tee -a "$LOG_FILE"
        } || {
            echo -e "\e[93mWarning: Could not drop database $DB_NAME (it may not exist).\033[0m" | tee -a "$LOG_FILE"
        }
    fi

    # Delete Configuration File
    CONFIG_PATH="/root/config.php"
    if [ -f "$CONFIG_PATH" ]; then
        sudo shred -u -n 5 "$CONFIG_PATH" && echo -e "\e[92mConfig file securely removed: $CONFIG_PATH\033[0m" | tee -a "$LOG_FILE" || {
            echo -e "\e[91mFailed to securely remove config file: $CONFIG_PATH\033[0m" | tee -a "$LOG_FILE"
        }
    fi

    # Check if any other instances remain before removing MySQL/Apache
    local remaining=0
    for cfg in /var/www/html/mitbot*/config.php; do
        if [ -f "$cfg" ]; then
            remaining=$((remaining + 1))
        fi
    done

    if [ $remaining -eq 0 ]; then
        # No more instances, remove MySQL and Apache
        echo -e "\e[33mNo more bot instances. Removing MySQL and dependencies...\033[0m" | tee -a "$LOG_FILE"
        sudo systemctl stop mysql
        sudo systemctl disable mysql
        sudo systemctl daemon-reload

        sudo apt --fix-broken install -y

        sudo apt-get purge -y mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-*
        sudo rm -rf /etc/mysql /var/lib/mysql /var/log/mysql /var/log/mysql.* /usr/lib/mysql /usr/include/mysql /usr/share/mysql
        sudo rm /lib/systemd/system/mysql.service
        sudo rm /etc/init.d/mysql

        sudo dpkg --remove --force-remove-reinstreq mysql-server mysql-server-8.0

        sudo find /etc/systemd /lib/systemd /usr/lib/systemd -name "*mysql*" -exec rm -f {} \;

        sudo apt-get purge -y mysql-server mysql-server-8.0 mysql-client mysql-client-8.0
        sudo apt-get purge -y mysql-client-core-8.0 mysql-server-core-8.0 mysql-common php-mysql php8.2-mysql php8.3-mysql php-mariadb-mysql-kbs

        sudo apt-get autoremove --purge -y
        sudo apt-get clean
        sudo apt-get update

        echo -e "\e[92mMySQL has been completely removed.\033[0m" | tee -a "$LOG_FILE"

        # Delete PHPMyAdmin
        echo -e "\e[33mRemoving PHPMyAdmin...\033[0m" | tee -a "$LOG_FILE"
        if dpkg -s phpmyadmin &>/dev/null; then
            sudo apt-get purge -y phpmyadmin && echo -e "\e[92mPHPMyAdmin removed.\033[0m" | tee -a "$LOG_FILE"
            sudo apt-get autoremove -y && sudo apt-get autoclean -y
        else
            echo -e "\e[93mPHPMyAdmin is not installed.\033[0m" | tee -a "$LOG_FILE"
        fi

        # Remove Apache
        echo -e "\e[33mRemoving Apache...\033[0m" | tee -a "$LOG_FILE"
        sudo systemctl stop apache2 || {
            echo -e "\e[91mFailed to stop Apache. Continuing anyway...\033[0m" | tee -a "$LOG_FILE"
        }
        sudo systemctl disable apache2 || {
            echo -e "\e[91mFailed to disable Apache. Continuing anyway...\033[0m" | tee -a "$LOG_FILE"
        }
        sudo apt-get purge -y apache2 apache2-utils apache2-bin apache2-data libapache2-mod-php* || {
            echo -e "\e[91mFailed to purge Apache packages.\033[0m" | tee -a "$LOG_FILE"
        }
        sudo apt-get autoremove --purge -y
        sudo apt-get autoclean -y
        sudo rm -rf /etc/apache2 /var/www/html

        # Delete Apache and PHP Settings
        echo -e "\e[33mRemoving Apache and PHP configurations...\033[0m" | tee -a "$LOG_FILE"
        sudo a2disconf phpmyadmin.conf &>/dev/null
        sudo rm -f /etc/apache2/conf-available/phpmyadmin.conf
        sudo systemctl restart apache2

        # Remove Unnecessary Packages
        echo -e "\e[33mRemoving additional packages...\033[0m" | tee -a "$LOG_FILE"
        sudo apt-get remove -y php-soap php-ssh2 libssh2-1-dev libssh2-1 \
            && echo -e "\e[92mRemoved additional PHP packages.\033[0m" | tee -a "$LOG_FILE" || echo -e "\e[93mSome additional PHP packages may not be installed.\033[0m" | tee -a "$LOG_FILE"

        # Reset Firewall (without changing SSL rules)
        echo -e "\e[33mResetting firewall rules (except SSL)...\033[0m" | tee -a "$LOG_FILE"
        sudo ufw delete allow 'Apache'
        sudo ufw reload
    else
        echo -e "\e[92mRemoved $(basename "$BOT_DIR"). $remaining instance(s) remaining.\033[0m" | tee -a "$LOG_FILE"
    fi

    echo -e "\e[92mMIT VPN Bot ($(basename "$BOT_DIR")) has been removed.\033[0m" | tee -a "$LOG_FILE"
}

function remove_bot_with_marzban() {
    echo -e "\e[33mRemoving MIT VPN Bot alongside Marzban...\033[0m" | tee -a "$LOG_FILE"

    # Define Bot Directory - find the first mitbot* instance
    local instances=()
    for cfg in /var/www/html/mitbot*/config.php; do
        if [ -f "$cfg" ]; then
            instances+=("$cfg")
        fi
    done

    if [ ${#instances[@]} -eq 0 ]; then
        echo -e "\e[93mWarning: No bot instances found. Assuming they were already removed.\033[0m" | tee -a "$LOG_FILE"
        DB_NAME=""
        DB_USER=""
    else
        local CONFIG_PATH="${instances[0]}"
        BOT_DIR=$(dirname "$CONFIG_PATH")
        # Get database credentials from config.php BEFORE removing the directory
        if [ -f "$CONFIG_PATH" ]; then
            DB_USER=$(grep '^\$usernamedb' "$CONFIG_PATH" | awk -F"'" '{print $2}')
            DB_NAME=$(grep '^\$dbname' "$CONFIG_PATH" | awk -F"'" '{print $2}')
            if [ -z "$DB_USER" ] || [ -z "$DB_NAME" ]; then
                echo -e "\e[91mError: Could not extract database credentials from $CONFIG_PATH. Using defaults.\033[0m" | tee -a "$LOG_FILE"
                DB_NAME=""
                DB_USER=""
            else
                echo -e "\e[92mFound database credentials: User=$DB_USER, Database=$DB_NAME\033[0m" | tee -a "$LOG_FILE"
            fi
        else
            echo -e "\e[93mWarning: config.php not found at $CONFIG_PATH.\033[0m" | tee -a "$LOG_FILE"
            DB_NAME=""
            DB_USER=""
        fi

        # Now remove the Bot Directory
        sudo rm -rf "$BOT_DIR" && echo -e "\e[92mBot directory removed: $BOT_DIR\033[0m" | tee -a "$LOG_FILE" || {
            echo -e "\e[91mFailed to remove bot directory: $BOT_DIR. Exiting...\033[0m" | tee -a "$LOG_FILE"
            exit 1
        }
    fi

    # Get MySQL root password from Marzban's .env
    ENV_FILE="/opt/marzban/.env"
    if [ -f "$ENV_FILE" ]; then
        MYSQL_ROOT_PASSWORD=$(grep "MYSQL_ROOT_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2 | tr -d '[:space:]' | sed 's/"//g')
        ROOT_USER="root"
    else
        echo -e "\e[91mError: Marzban .env file not found. Cannot proceed without MySQL root password.\033[0m" | tee -a "$LOG_FILE"
        exit 1
    fi

    # Find MySQL container
    MYSQL_CONTAINER=$(docker ps -q --filter "name=mysql" --no-trunc)
    if [ -z "$MYSQL_CONTAINER" ]; then
        echo -e "\e[91mError: Could not find a running MySQL container. Ensure Marzban is running.\033[0m" | tee -a "$LOG_FILE"
        exit 1
    fi

    # Remove database
    if [ -n "$DB_NAME" ]; then
        echo -e "\e[33mRemoving database $DB_NAME...\033[0m" | tee -a "$LOG_FILE"
        docker exec "$MYSQL_CONTAINER" bash -c "mysql -u '$ROOT_USER' -p'$MYSQL_ROOT_PASSWORD' -e \"DROP DATABASE IF EXISTS $DB_NAME;\"" && {
            echo -e "\e[92mDatabase $DB_NAME removed successfully.\033[0m" | tee -a "$LOG_FILE"
        } || {
            echo -e "\e[91mFailed to remove database $DB_NAME.\033[0m" | tee -a "$LOG_FILE"
        }
    fi

    # Remove user if DB_USER is available
    if [ -n "$DB_USER" ]; then
        echo -e "\e[33mRemoving database user $DB_USER...\033[0m" | tee -a "$LOG_FILE"
        docker exec "$MYSQL_CONTAINER" bash -c "mysql -u '$ROOT_USER' -p'$MYSQL_ROOT_PASSWORD' -e \"DROP USER IF EXISTS '$DB_USER'@'%'; FLUSH PRIVILEGES;\"" && {
            echo -e "\e[92mUser $DB_USER removed successfully.\033[0m" | tee -a "$LOG_FILE"
        } || {
            echo -e "\e[91mFailed to remove user $DB_USER.\033[0m" | tee -a "$LOG_FILE"
        }
    else
        echo -e "\e[93mWarning: No database user specified. Checking for non-default users...\033[0m" | tee -a "$LOG_FILE"
        # Check for non-default users
        MIT_USERS=$(docker exec "$MYSQL_CONTAINER" bash -c "mysql -u '$ROOT_USER' -p'$MYSQL_ROOT_PASSWORD' -e \"SELECT User FROM mysql.user WHERE User NOT IN ('root', 'mysql.infoschema', 'mysql.session', 'mysql.sys', 'marzban');\"" | grep -v "User" | awk '{print $1}')
        if [ -n "$MIT_USERS" ]; then
            for user in $MIT_USERS; do
                echo -e "\e[33mRemoving detected non-default user: $user...\033[0m" | tee -a "$LOG_FILE"
                docker exec "$MYSQL_CONTAINER" bash -c "mysql -u '$ROOT_USER' -p'$MYSQL_ROOT_PASSWORD' -e \"DROP USER IF EXISTS '$user'@'%'; FLUSH PRIVILEGES;\"" && {
                    echo -e "\e[92mUser $user removed successfully.\033[0m" | tee -a "$LOG_FILE"
                } || {
                    echo -e "\e[91mFailed to remove user $user.\033[0m" | tee -a "$LOG_FILE"
                }
            done
        else
            echo -e "\e[93mNo non-default users found.\033[0m" | tee -a "$LOG_FILE"
        fi
    fi

    # Remove Apache
    echo -e "\e[33mRemoving Apache...\033[0m" | tee -a "$LOG_FILE"
    sudo systemctl stop apache2 || {
        echo -e "\e[91mFailed to stop Apache. Continuing anyway...\033[0m" | tee -a "$LOG_FILE"
    }
    sudo systemctl disable apache2 || {
        echo -e "\e[91mFailed to disable Apache. Continuing anyway...\033[0m" | tee -a "$LOG_FILE"
    }
    sudo apt-get purge -y apache2 apache2-utils apache2-bin apache2-data libapache2-mod-php* || {
        echo -e "\e[91mFailed to purge Apache packages.\033[0m" | tee -a "$LOG_FILE"
    }
    sudo apt-get autoremove --purge -y
    sudo apt-get autoclean -y
    sudo rm -rf /etc/apache2 /var/www/html

    # Reset Firewall (only remove Apache rule, keep SSL)
    echo -e "\e[33mResetting firewall rules (keeping SSL)...\033[0m" | tee -a "$LOG_FILE"
    sudo ufw delete allow 'Apache' || {
        echo -e "\e[91mFailed to remove Apache rule from UFW.\033[0m" | tee -a "$LOG_FILE"
    }
    sudo ufw reload

    echo -e "\e[92mMIT VPN Bot has been removed alongside Marzban. SSL certificates remain intact.\033[0m" | tee -a "$LOG_FILE"
}

# Extract database credentials from config.php
function extract_db_credentials() {
    local config_path="${1:-}"

    # If no config path provided, detect instances
    if [ -z "$config_path" ]; then
        local instances=()
        for cfg in /var/www/html/mitbot*/config.php; do
            if [ -f "$cfg" ]; then
                instances+=("$cfg")
            fi
        done

        if [ ${#instances[@]} -eq 0 ]; then
            echo -e "\033[31m[ERROR]\033[0m No MIT VPN Bot config files found."
            return 1
        fi

        if [ ${#instances[@]} -eq 1 ]; then
            config_path="${instances[0]}"
        else
            echo -e "\033[36mMultiple bot instances found:\033[0m"
            for i in "${!instances[@]}"; do
                local name=$(basename "$(dirname "${instances[$i]}")")
                echo -e "\033[33m$((i+1)))\033[0m $name"
            done
            echo ""
            read -p "Select instance [1-${#instances[@]}]: " choice
            if [[ "$choice" -ge 1 && "$choice" -le ${#instances[@]} ]]; then
                config_path="${instances[$((choice-1))]}"
            else
                echo -e "\033[31m[ERROR]\033[0m Invalid selection."
                return 1
            fi
        fi
    fi

    CONFIG_PATH="$config_path"
    if [ -f "$CONFIG_PATH" ]; then
        DB_USER=$(grep '^\$usernamedb' "$CONFIG_PATH" | awk -F"'" '{print $2}')
        DB_PASS=$(grep '^\$passworddb' "$CONFIG_PATH" | awk -F"'" '{print $2}')
        DB_NAME=$(grep '^\$dbname' "$CONFIG_PATH" | awk -F"'" '{print $2}')
        TELEGRAM_TOKEN=$(grep '^\$APIKEY' "$CONFIG_PATH" | awk -F"'" '{print $2}')
        TELEGRAM_CHAT_ID=$(grep '^\$adminnumber' "$CONFIG_PATH" | awk -F"'" '{print $2}')
        if [ -z "$DB_USER" ] || [ -z "$DB_PASS" ] || [ -z "$DB_NAME" ] || [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
            echo -e "\033[31m[ERROR]\033[0m Failed to extract required credentials from $CONFIG_PATH."
            return 1
        fi
        return 0
    else
        echo -e "\033[31m[ERROR]\033[0m config.php not found at $CONFIG_PATH."
        return 1
    fi
}

# Translate cron schedule to human-readable format
function translate_cron() {
    local cron_line="$1"
    local schedule=""
    case "$cron_line" in
        "* * * * *"*) schedule="Every Minute" ;;
        "0 * * * *"*) schedule="Every Hour" ;;
        "0 0 * * *"*) schedule="Every Day" ;;
        "0 0 * * 0"*) schedule="Every Week" ;;
        *) schedule="Custom Schedule ($cron_line)" ;;
    esac
    echo "$schedule"
}

# Export Database Function
function export_database() {
    echo -e "\033[33mChecking database configuration...\033[0m"

    if ! extract_db_credentials; then
        return 1
    fi

    # Check if Marzban is installed
    if check_marzban_installed; then
        echo -e "\033[31m[ERROR]\033[0m Exporting database is not supported when Marzban is installed due to database being managed by Docker."
        return 1
    fi

    echo -e "\033[33mVerifying database existence...\033[0m"

    if ! mysql -u "$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME;" 2>/dev/null; then
        echo -e "\033[31m[ERROR]\033[0m Database $DB_NAME does not exist or credentials are incorrect."
        return 1
    fi

    BACKUP_FILE="/root/${DB_NAME}_backup.sql"
    echo -e "\033[33mCreating backup at $BACKUP_FILE...\033[0m"

    if ! mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$BACKUP_FILE"; then
        echo -e "\033[31m[ERROR]\033[0m Failed to create database backup."
        return 1
    fi

    echo -e "\033[32mBackup successfully created at $BACKUP_FILE.\033[0m"
}
# Import Database Function
function import_database() {
    echo -e "\033[33mChecking database configuration...\033[0m"

    if ! extract_db_credentials; then
        return 1
    fi

    # Check if Marzban is installed
    if check_marzban_installed; then
        echo -e "\033[31m[ERROR]\033[0m Importing database is not supported when Marzban is installed due to database being managed by Docker."
        return 1
    fi

    echo -e "\033[33mVerifying database existence...\033[0m"

    if ! mysql -u "$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME;" 2>/dev/null; then
        echo -e "\033[31m[ERROR]\033[0m Database $DB_NAME does not exist or credentials are incorrect."
        return 1
    fi

    while true; do
        read -p "Enter the path to the backup file [default: /root/${DB_NAME}_backup.sql]: " BACKUP_FILE
        BACKUP_FILE=${BACKUP_FILE:-/root/${DB_NAME}_backup.sql}

        if [[ -f "$BACKUP_FILE" && "$BACKUP_FILE" =~ \.sql$ ]]; then
            break
        else
            echo -e "\033[31m[ERROR]\033[0m Invalid file path or format. Please provide a valid .sql file."
        fi
    done

    echo -e "\033[33mImporting backup from $BACKUP_FILE...\033[0m"

    if ! mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$BACKUP_FILE"; then
        echo -e "\033[31m[ERROR]\033[0m Failed to import database from backup file."
        return 1
    fi

    echo -e "\033[32mDatabase successfully imported from $BACKUP_FILE.\033[0m"
}

# Function for automated backup
function auto_backup() {
    echo -e "\033[36mConfigure Automated Backup\033[0m"

    # Detect all bot instances
    local instances=()
    for cfg in /var/www/html/mitbot*/config.php; do
        if [ -f "$cfg" ]; then
            instances+=("$cfg")
        fi
    done

    if [ ${#instances[@]} -eq 0 ]; then
        echo -e "\033[31m[ERROR]\033[0m No MIT VPN Bot instances found."
        echo -e "\033[33mExiting...\033[0m"
        sleep 2
        return 1
    fi

    # Select instance
    local SELECTED_CONFIG=""
    if [ ${#instances[@]} -eq 1 ]; then
        SELECTED_CONFIG="${instances[0]}"
        echo -e "\033[92mFound bot instance: $(basename "$(dirname "$SELECTED_CONFIG")")\033[0m"
    else
        echo -e "\033[36mMultiple bot instances found:\033[0m"
        for i in "${!instances[@]}"; do
            local name=$(basename "$(dirname "${instances[$i]}")")
            echo -e "\033[33m$((i+1)))\033[0m $name"
        done
        echo ""
        read -p "Select instance to configure backup for [1-${#instances[@]}]: " choice
        if [[ "$choice" -ge 1 && "$choice" -le ${#instances[@]} ]]; then
            SELECTED_CONFIG="${instances[$((choice-1))]}"
        else
            echo -e "\033[31mInvalid selection. Exiting...\033[0m"
            return 1
        fi
    fi

    BOT_DIR=$(dirname "$SELECTED_CONFIG")

    # Extract credentials
    if ! extract_db_credentials "$SELECTED_CONFIG"; then
        return 1
    fi

    # Determine backup script based on Marzban presence
    if check_marzban_installed; then
        echo -e "\033[41m[NOTICE]\033[0m \033[33mMarzban detected. Using Marzban-compatible backup.\033[0m"
        BACKUP_SCRIPT="/root/backup_mit_$(basename "$BOT_DIR").sh"
        MYSQL_CONTAINER=$(docker ps -q --filter "name=mysql" --no-trunc)
        if [ -z "$MYSQL_CONTAINER" ]; then
            echo -e "\033[31m[ERROR]\033[0m No running MySQL container found for Marzban."
            return 1
        fi
        # Create Marzban backup script
        cat <<EOF > "$BACKUP_SCRIPT"
#!/bin/bash
BACKUP_FILE="/root/\${DB_NAME}_\$(date +\"%Y%m%d_%H%M%S\").sql"
docker exec $MYSQL_CONTAINER mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "\$BACKUP_FILE"
if [ \$? -eq 0 ]; then
    curl -F document=@"\$BACKUP_FILE" "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_CHAT_ID"
    rm "\$BACKUP_FILE"
else
    echo -e "\033[31m[ERROR]\033[0m Failed to create Marzban database backup."
fi
EOF
    else
        echo -e "\033[33mUsing standard backup for $(basename "$BOT_DIR").\033[0m"
        BACKUP_SCRIPT="/root/mit_backup_$(basename "$BOT_DIR").sh"
        # Verify database existence
        if ! mysql -u "$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME;" 2>/dev/null; then
            echo -e "\033[31m[ERROR]\033[0m Database $DB_NAME does not exist or credentials are incorrect."
            return 1
        fi
        # Create standard backup script
        cat <<EOF > "$BACKUP_SCRIPT"
#!/bin/bash
BACKUP_FILE="/root/\${DB_NAME}_\$(date +\"%Y%m%d_%H%M%S\").sql"
mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "\$BACKUP_FILE"
if [ \$? -eq 0 ]; then
    curl -F document=@"\$BACKUP_FILE" "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_CHAT_ID"
    rm "\$BACKUP_FILE"
else
    echo -e "\033[31m[ERROR]\033[0m Failed to create database backup."
fi
EOF
    fi

    # Make the script executable
    chmod +x "$BACKUP_SCRIPT"

    # Check current cron and translate it
    CURRENT_CRON=$(crontab -l 2>/dev/null | grep "$BACKUP_SCRIPT" | grep -v "^#")
    if [ -n "$CURRENT_CRON" ]; then
        SCHEDULE=$(translate_cron "$CURRENT_CRON")
        echo -e "\033[33mCurrent Backup Schedule:\033[0m $SCHEDULE"
    else
        echo -e "\033[33mNo active backup schedule found.\033[0m"
    fi

    # Show backup frequency options
    echo -e "\033[36m1) Every Minute\033[0m"
    echo -e "\033[36m2) Every Hour\033[0m"
    echo -e "\033[36m3) Every Day\033[0m"
    echo -e "\033[36m4) Every Week\033[0m"
    echo -e "\033[36m5) Disable Backup\033[0m"
    echo -e "\033[36m6) Back to Menu\033[0m"
    echo ""
    read -p "Select an option [1-6]: " backup_option

    # Function to update cron
    update_cron() {
        local cron_line="$1"
        if [ -n "$CURRENT_CRON" ]; then
            crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT" | crontab - && {
                echo -e "\033[92mRemoved previous backup schedule.\033[0m"
            } || {
                echo -e "\033[31mFailed to remove existing cron.\033[0m"
            }
        fi
        if [ -n "$cron_line" ]; then
            (crontab -l 2>/dev/null; echo "$cron_line") | crontab - && {
                echo -e "\033[92mBackup scheduled: $(translate_cron "$cron_line")\033[0m"
                bash "$BACKUP_SCRIPT" &>/dev/null &
            } || {
                echo -e "\033[31mFailed to schedule backup.\033[0m"
            }
        fi
    }

    # Process user choice
    case $backup_option in
        1) update_cron "* * * * * bash $BACKUP_SCRIPT" ;;
        2) update_cron "0 * * * * bash $BACKUP_SCRIPT" ;;
        3) update_cron "0 0 * * * bash $BACKUP_SCRIPT" ;;
        4) update_cron "0 0 * * 0 bash $BACKUP_SCRIPT" ;;
        5)
            if [ -n "$CURRENT_CRON" ]; then
                crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT" | crontab - && {
                    echo -e "\033[92mAutomated backup disabled.\033[0m"
                } || {
                    echo -e "\033[31mFailed to disable backup.\033[0m"
                }
            else
                echo -e "\033[93mNo backup schedule to disable.\033[0m"
            fi
            ;;
        6) show_menu ;;
        *)
            echo -e "\033[31mInvalid option. Please try again.\033[0m"
            auto_backup
            ;;
    esac
}

# Function to renew SSL certificates
function renew_ssl() {
    echo -e "\033[33mStarting SSL renewal process...\033[0m"

    if ! command -v certbot &>/dev/null; then
        echo -e "\033[31m[ERROR]\033[0m Certbot is not installed. Please install Certbot to proceed."
        return 1
    fi

    # Stop Apache to free port 80
    echo -e "\033[33mStopping Apache...\033[0m"
    sudo systemctl stop apache2 || {
        echo -e "\033[31m[ERROR]\033[0m Failed to stop Apache. Exiting..."
        return 1
    }

    # Renew SSL certificates
    if sudo certbot renew; then
        echo -e "\033[32mSSL certificates successfully renewed.\033[0m"
    else
        echo -e "\033[31m[ERROR]\033[0m SSL renewal failed. Please check Certbot logs for more details."
        # Restart Apache even if renewal failed
        sudo systemctl start apache2
        return 1
    fi

    # Restart Apache
    echo -e "\033[33mRestarting Apache...\033[0m"
    sudo systemctl restart apache2 || {
        echo -e "\033[31m[WARNING]\033[0m Failed to restart Apache. Please check manually."
    }
}

function change_domain() {
    # Detect all bot instances
    local instances=()
    for cfg in /var/www/html/mitbot*/config.php; do
        if [ -f "$cfg" ]; then
            instances+=("$cfg")
        fi
    done

    if [ ${#instances[@]} -eq 0 ]; then
        echo -e "\033[31m[ERROR]\033[0m No MIT VPN Bot instances found."
        return 1
    fi

    # Select instance
    local SELECTED_CONFIG=""
    if [ ${#instances[@]} -eq 1 ]; then
        SELECTED_CONFIG="${instances[0]}"
        echo -e "\033[92mFound bot instance: $(basename "$(dirname "$SELECTED_CONFIG")")\033[0m"
    else
        echo -e "\033[36mMultiple bot instances found:\033[0m"
        for i in "${!instances[@]}"; do
            local name=$(basename "$(dirname "${instances[$i]}")")
            echo -e "\033[33m$((i+1)))\033[0m $name"
        done
        echo ""
        read -p "Select instance to change domain for [1-${#instances[@]}]: " choice
        if [[ "$choice" -ge 1 && "$choice" -le ${#instances[@]} ]]; then
            SELECTED_CONFIG="${instances[$((choice-1))]}"
        else
            echo -e "\033[31mInvalid selection. Exiting...\033[0m"
            return 1
        fi
    fi

    local BOT_DIR_NAME=$(basename "$(dirname "$SELECTED_CONFIG")")

    local new_domain
    while [[ ! "$new_domain" =~ ^[a-zA-Z0-9.-]+$ ]]; do
        read -p "Enter new domain: " new_domain
        [[ ! "$new_domain" =~ ^[a-zA-Z0-9.-]+$ ]] && echo -e "\033[31mInvalid domain format\033[0m"
    done

    echo -e "\033[33mStopping Apache to configure SSL...\033[0m"
    if ! sudo systemctl stop apache2; then
        echo -e "\033[31m[ERROR] Failed to stop Apache!\033[0m"
        return 1
    fi

    echo -e "\033[33mConfiguring SSL for new domain...\033[0m"
    if ! sudo certbot --apache --redirect --agree-tos --preferred-challenges http -d "$new_domain"; then
        echo -e "\033[31m[ERROR] SSL configuration failed!\033[0m"
        echo -e "\033[33mCleaning up...\033[0m"
        sudo certbot delete --cert-name "$new_domain" 2>/dev/null
        echo -e "\033[33mRestarting Apache after cleanup...\033[0m"
        sudo systemctl start apache2 || echo -e "\033[31m[ERROR] Failed to restart Apache!\033[0m"
        return 1
    fi

    echo -e "\033[33mRestarting Apache after SSL configuration...\033[0m"
    if ! sudo systemctl start apache2; then
        echo -e "\033[31m[ERROR] Failed to restart Apache!\033[0m"
        return 1
    fi

    CONFIG_FILE="$SELECTED_CONFIG"
    if [ -f "$CONFIG_FILE" ]; then
        sudo cp "$CONFIG_FILE" "$CONFIG_FILE.$(date +%s).bak"

        sudo sed -i "s|\$domainhosts = '.*/${BOT_DIR_NAME}';|\$domainhosts = '${new_domain}/${BOT_DIR_NAME}';|" "$CONFIG_FILE"

        NEW_SECRET=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9')
        sudo sed -i "s/\$secrettoken = '.*';/\$secrettoken = '${NEW_SECRET%%}';/" "$CONFIG_FILE"

        BOT_TOKEN=$(awk -F"'" '/\$APIKEY/{print $2}' "$CONFIG_FILE")
        curl -s -o /dev/null -F "url=https://${new_domain}/${BOT_DIR_NAME}/index.php" \
             -F "secret_token=${NEW_SECRET}" \
             "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook" || {
            echo -e "\033[33m[WARNING] Webhook update failed\033[0m"
        }
    else
        echo -e "\033[31m[CRITICAL] Config file missing!\033[0m"
        return 1
    fi

    if curl -sI "https://${new_domain}" | grep -q "200 OK"; then
        echo -e "\033[32mDomain successfully migrated to ${new_domain}\033[0m"
        echo -e "\033[33mOld domain configuration has been automatically cleaned up\033[0m"
    else
        echo -e "\033[31m[WARNING] Final verification failed!\033[0m"
        echo -e "\033[33mPlease check:\033[0m"
        echo -e "1. DNS settings for ${new_domain}"
        echo -e "2. Apache virtual host configuration"
        echo -e "3. Firewall settings"
        return 1
    fi
}

# ============================================================================
# Additional Bot Management Functions
# ============================================================================

# Sub-menu for Additional Bot Management
function manage_additional_bots() {
    clear
    echo -e "\033[1;36m========================================\033[0m"
    echo -e "\033[1;36m    Additional Bot Management\033[0m"
    echo -e "\033[1;36m========================================\033[0m"
    echo ""
    echo -e "\033[1;36m1)\033[0m Install Additional Bot"
    echo -e "\033[1;36m2)\033[0m Update Additional Bot"
    echo -e "\033[1;36m3)\033[0m Remove Additional Bot"
    echo -e "\033[1;36m4)\033[0m Export Additional Bot Database"
    echo -e "\033[1;36m5)\033[0m Import Additional Bot Database"
    echo -e "\033[1;36m6)\033[0m Configure Automated Backup for Additional Bot"
    echo -e "\033[1;36m7)\033[0m Back to Main Menu"
    echo ""
    read -p "Select an option [1-7]: " option
    case $option in
        1) install_additional_bot ;;
        2) update_additional_bot ;;
        3) remove_additional_bot ;;
        4) export_additional_bot_database ;;
        5) import_additional_bot_database ;;
        6) configure_backup_additional_bot ;;
        7) show_menu ;;
        *)
            echo -e "\033[31mInvalid option. Please try again.\033[0m"
            sleep 1
            manage_additional_bots
            ;;
    esac
}

# Install Additional Bot on a separate domain
function install_additional_bot() {
    echo -e "\033[32mInstalling Additional Bot...\033[0m\n"

    # Read root DB credentials
    if [ ! -f "/root/confmit/dbrootmit.txt" ]; then
        echo -e "\e[91mError: /root/confmit/dbrootmit.txt not found. Please install a main bot first.\033[0m"
        return 1
    fi

    ROOT_PASSWORD=$(cat /root/confmit/dbrootmit.txt | grep '$pass' | cut -d"'" -f2)
    ROOT_USER=$(cat /root/confmit/dbrootmit.txt | grep '$user' | cut -d"'" -f2)

    if [ -z "$ROOT_PASSWORD" ] || [ -z "$ROOT_USER" ]; then
        echo -e "\e[91mError: Could not read database credentials from /root/confmit/dbrootmit.txt.\033[0m"
        return 1
    fi

    # Prompt for bot name
    while true; do
        printf "\e[33m[+] \e[36mBot name (alphanumeric, no spaces): \033[0m"
        read BOT_NAME
        if [[ "$BOT_NAME" =~ ^[a-zA-Z0-9_]+$ ]] && [ -n "$BOT_NAME" ]; then
            BOT_DIR="/var/www/html/addbot_${BOT_NAME}"
            if [ -d "$BOT_DIR" ]; then
                echo -e "\e[91mError: A bot with this name already exists.\033[0m"
            else
                break
            fi
        else
            echo -e "\e[91mInvalid bot name. Use only letters, numbers, and underscores.\033[0m"
        fi
    done

    # Prompt for domain
    while true; do
        printf "\e[33m[+] \e[36mDomain (e.g., example.com): \033[0m"
        read ADD_DOMAIN
        if [[ "$ADD_DOMAIN" =~ ^[a-zA-Z0-9.-]+$ ]]; then
            break
        else
            echo -e "\e[91mInvalid domain format. Please try again.\033[0m"
        fi
    done

    # Prompt for bot token
    while true; do
        printf "\e[33m[+] \e[36mBot Token: \033[0m"
        read ADD_BOT_TOKEN
        if [[ "$ADD_BOT_TOKEN" =~ ^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$ ]]; then
            break
        else
            echo -e "\e[91mInvalid bot token format. Please try again.\033[0m"
        fi
    done

    # Prompt for chat ID
    while true; do
        printf "\e[33m[+] \e[36mChat ID: \033[0m"
        read ADD_CHAT_ID
        if [[ "$ADD_CHAT_ID" =~ ^-?[0-9]+$ ]]; then
            break
        else
            echo -e "\e[91mInvalid chat ID format. Please try again.\033[0m"
        fi
    done

    # Resolve bot username
    echo -e "\033[33mResolving bot username from token...\033[0m"
    ADD_BOTNAME=$(curl -s "https://api.telegram.org/bot${ADD_BOT_TOKEN}/getMe" | grep -oP '"username":"\K[^"]+')
    if [ -n "$ADD_BOTNAME" ]; then
        echo -e "\033[32mBot username resolved: @$ADD_BOTNAME\033[0m"
    else
        printf "\e[33m[+] \e[36mBot Username (could not auto-resolve): \033[0m"
        read ADD_BOTNAME
        while [ -z "$ADD_BOTNAME" ]; do
            echo -e "\e[91mBot username cannot be empty.\033[0m"
            printf "\e[33m[+] \e[36mBot Username: \033[0m"
            read ADD_BOTNAME
        done
    fi

    # Create SSL certificate
    echo -e "\033[33mSetting up SSL certificate...\033[0m"
    sudo systemctl stop apache2 2>/dev/null
    sudo ufw allow 80 2>/dev/null
    sudo ufw allow 443 2>/dev/null
    sudo certbot certonly --standalone --agree-tos --preferred-challenges http -d "$ADD_DOMAIN" || {
        echo -e "\e[91mError: Failed to generate SSL certificate.\033[0m"
        sudo systemctl start apache2 2>/dev/null
        return 1
    }
    sudo apt install python3-certbot-apache -y 2>/dev/null
    sudo certbot --apache --agree-tos --preferred-challenges http -d "$ADD_DOMAIN" || {
        echo -e "\e[91mError: Failed to configure SSL with Certbot.\033[0m"
        sudo systemctl start apache2 2>/dev/null
        return 1
    }
    sudo systemctl enable apache2 2>/dev/null
    sudo systemctl start apache2 2>/dev/null

    # Create Apache VirtualHost
    sudo bash -c "cat > /etc/apache2/sites-available/addbot_${BOT_NAME}.conf << VHOST
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
VHOST"
    sudo a2ensite "addbot_${BOT_NAME}.conf" 2>/dev/null
    sudo systemctl reload apache2 2>/dev/null

    # Clone repository
    echo -e "\033[33mDownloading bot files...\033[0m"
    TEMP_DIR="/tmp/addbot_${BOT_NAME}"
    mkdir -p "$TEMP_DIR"
    ZIP_URL=$(curl -s https://api.github.com/repos/Liwyd/mirzaMIT/releases/latest | grep "zipball_url" | cut -d '"' -f 4)
    wget -O "$TEMP_DIR/bot.zip" "$ZIP_URL" || {
        echo -e "\e[91mError: Failed to download bot files.\033[0m"
        rm -rf "$TEMP_DIR"
        return 1
    }
    unzip "$TEMP_DIR/bot.zip" -d "$TEMP_DIR" 2>/dev/null
    EXTRACTED_DIR=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d)
    sudo mkdir -p "$BOT_DIR"
    sudo mv "$EXTRACTED_DIR"/* "$BOT_DIR/" || {
        echo -e "\e[91mError: Failed to move bot files.\033[0m"
        rm -rf "$TEMP_DIR"
        return 1
    }
    rm -rf "$TEMP_DIR"
    sudo chown -R www-data:www-data "$BOT_DIR"
    sudo chmod -R 755 "$BOT_DIR"

    # Create database
    DB_NAME="mitbot_${BOT_NAME}"
    randomdbpass=$(openssl rand -base64 10 | tr -dc 'a-zA-Z0-9' | cut -c1-8)
    randomdbuser=$(openssl rand -base64 10 | tr -dc 'a-zA-Z' | cut -c1-8)

    printf "\e[33m[+] \e[36mDatabase username (default: %s): \033[0m" "$randomdbuser"
    read ADD_DBUSER
    ADD_DBUSER="${ADD_DBUSER:-$randomdbuser}"

    printf "\e[33m[+] \e[36mDatabase password (default: %s): \033[0m" "$randomdbpass"
    read -s ADD_DBPASS
    echo
    ADD_DBPASS="${ADD_DBPASS:-$randomdbpass}"

    mysql -u "$ROOT_USER" -p"$ROOT_PASSWORD" -e "CREATE DATABASE \`$DB_NAME\`;" \
        -e "CREATE USER '$ADD_DBUSER'@'%' IDENTIFIED WITH mysql_native_password BY '$ADD_DBPASS';GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$ADD_DBUSER'@'%';FLUSH PRIVILEGES;" \
        -e "CREATE USER '$ADD_DBUSER'@'localhost' IDENTIFIED WITH mysql_native_password BY '$ADD_DBPASS';GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$ADD_DBUSER'@'localhost';FLUSH PRIVILEGES;" || {
        echo -e "\e[91mError: Failed to create database or user.\033[0m"
        return 1
    }
    echo -e "\n\e[95mDatabase '$DB_NAME' created.\033[0m"

    # Generate config.php
    MIT_SECRET=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9')
    secrettoken=$(openssl rand -base64 10 | tr -dc 'a-zA-Z0-9' | cut -c1-8)
    ASAS="$"

    cat <<EOF > "$BOT_DIR/config.php"
<?php
define('MIT_SECRET_CODE', '${MIT_SECRET}');
${ASAS}APIKEY = '${ADD_BOT_TOKEN}';
${ASAS}usernamedb = '${ADD_DBUSER}';
${ASAS}passworddb = '${ADD_DBPASS}';
${ASAS}dbname = '${DB_NAME}';
${ASAS}domainhosts = '${ADD_DOMAIN}/addbot_${BOT_NAME}';
${ASAS}adminnumber = '${ADD_CHAT_ID}';
${ASAS}usernamebot = '${ADD_BOTNAME}';
${ASAS}secrettoken = '${secrettoken}';
${ASAS}connect = mysqli_connect('localhost', \$usernamedb, \$passworddb, \$dbname);
if (${ASAS}connect->connect_error) {
die(' The connection to the database failed:' . ${ASAS}connect->connect_error);
}
mysqli_set_charset(${ASAS}connect, 'utf8mb4');
\$options = [
PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
PDO::ATTR_EMULATE_PREPARES   => false,
];
\$dsn = "mysql:host=localhost;dbname=\${ASAS}dbname;charset=utf8mb4";
try {
\$pdo = new PDO(\$dsn, \$usernamedb, \$passworddb, \$options);
} catch (\PDOException \$e) {
throw new \PDOException(\$e->getMessage(), (int)\$e->getCode());
}
?>
EOF

    # Set webhook
    curl -F "url=https://${ADD_DOMAIN}/addbot_${BOT_NAME}/index.php" \
         -F "secret_token=${secrettoken}" \
         "https://api.telegram.org/bot${ADD_BOT_TOKEN}/setWebhook" || {
        echo -e "\e[91mError: Failed to set webhook.\033[0m"
        return 1
    }

    # Send confirmation
    MESSAGE="✅ Additional bot '$BOT_NAME' is installed! Send /start to begin."
    curl -s -X POST "https://api.telegram.org/bot${ADD_BOT_TOKEN}/sendMessage" -d chat_id="${ADD_CHAT_ID}" -d text="$MESSAGE" 2>/dev/null

    # Run table.php
    sleep 1
    curl -s "https://${ADD_DOMAIN}/addbot_${BOT_NAME}/table.php" || {
        echo -e "\e[93mWarning: Could not run table.php.\033[0m"
    }

    clear
    echo " "
    echo -e "\e[102mAdditional Bot: https://${ADD_DOMAIN}\033[0m"
    echo -e "\e[104mDatabase address: https://${ADD_DOMAIN}/phpmyadmin\033[0m"
    echo -e "\e[33mBot name: \e[36m${BOT_NAME}\033[0m"
    echo -e "\e[33mDatabase name: \e[36m${DB_NAME}\033[0m"
    echo -e "\e[33mDatabase username: \e[36m${ADD_DBUSER}\033[0m"
    echo -e "\e[33mDatabase password: \e[36m${ADD_DBPASS}\033[0m"
    echo " "
    echo -e "Additional Bot Installed Successfully"
}

# Update Additional Bot
function update_additional_bot() {
    echo -e "\033[32mUpdating Additional Bot...\033[0m\n"

    # List additional bots (exclude mitbot* directories)
    local addbots=()
    for dir in /var/www/html/addbot_*; do
        if [ -d "$dir" ] && [ -f "$dir/config.php" ]; then
            addbots+=("$dir")
        fi
    done

    if [ ${#addbots[@]} -eq 0 ]; then
        echo -e "\e[91mError: No additional bots found.\033[0m"
        return 1
    fi

    echo -e "\e[36mAvailable additional bots:\033[0m"
    for i in "${!addbots[@]}"; do
        echo -e "\e[33m$((i+1)))\033[0m $(basename "${addbots[$i]}")"
    done
    echo ""
    read -p "Select bot to update [1-${#addbots[@]}]: " choice
    if [[ "$choice" -lt 1 || "$choice" -gt ${#addbots[@]} ]]; then
        echo -e "\e[91mInvalid selection.\033[0m"
        return 1
    fi

    local BOT_DIR="${addbots[$((choice-1))]}"
    local BOT_NAME=$(basename "$BOT_DIR")

    # Download latest
    echo -e "\033[33mDownloading latest version...\033[0m"
    TEMP_DIR="/tmp/addbot_update"
    mkdir -p "$TEMP_DIR"
    ZIP_URL=$(curl -s https://api.github.com/repos/Liwyd/mirzaMIT/releases/latest | grep "zipball_url" | cut -d '"' -f4)
    wget -O "$TEMP_DIR/bot.zip" "$ZIP_URL" || {
        echo -e "\e[91mError: Failed to download update.\033[0m"
        rm -rf "$TEMP_DIR"
        return 1
    }
    unzip "$TEMP_DIR/bot.zip" -d "$TEMP_DIR" 2>/dev/null
    EXTRACTED_DIR=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d)

    # Backup config
    CONFIG_PATH="${BOT_DIR}/config.php"
    TEMP_CONFIG="/root/addbot_config_backup.php"
    cp "$CONFIG_PATH" "$TEMP_CONFIG"

    # Remove old, copy new
    sudo rm -rf "$BOT_DIR"
    sudo mkdir -p "$BOT_DIR"
    sudo mv "$EXTRACTED_DIR"/* "$BOT_DIR/" || {
        echo -e "\e[91mError: Failed to copy new files.\033[0m"
        rm -rf "$TEMP_DIR"
        return 1
    }

    # Restore config
    sudo mv "$TEMP_CONFIG" "$CONFIG_PATH"

    # Set permissions
    sudo chown -R www-data:www-data "$BOT_DIR/"
    sudo chmod -R 755 "$BOT_DIR/"

    # Run table.php
    URL=$(grep '\$domainhosts' "$CONFIG_PATH" | cut -d"'" -f2)
    curl -s "https://$URL/table.php" || {
        echo -e "\e[93mWarning: table.php execution failed.\033[0m"
    }

    rm -rf "$TEMP_DIR"
    echo -e "\n\e[92mAdditional bot '$BOT_NAME' updated successfully!\033[0m"
}

# Remove Additional Bot
function remove_additional_bot() {
    echo -e "\033[32mRemoving Additional Bot...\033[0m\n"

    # List additional bots
    local addbots=()
    for dir in /var/www/html/addbot_*; do
        if [ -d "$dir" ] && [ -f "$dir/config.php" ]; then
            addbots+=("$dir")
        fi
    done

    if [ ${#addbots[@]} -eq 0 ]; then
        echo -e "\e[91mError: No additional bots found.\033[0m"
        return 1
    fi

    echo -e "\e[36mAvailable additional bots:\033[0m"
    for i in "${!addbots[@]}"; do
        echo -e "\e[33m$((i+1)))\033[0m $(basename "${addbots[$i]}")"
    done
    echo ""
    read -p "Select bot to remove [1-${#addbots[@]}]: " choice
    if [[ "$choice" -lt 1 || "$choice" -gt ${#addbots[@]} ]]; then
        echo -e "\e[91mInvalid selection.\033[0m"
        return 1
    fi

    local BOT_DIR="${addbots[$((choice-1))]}"
    local BOT_NAME=$(basename "$BOT_DIR")

    # Confirmation
    read -p "Are you sure you want to remove '$BOT_NAME'? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        echo "Aborting..."
        return 0
    fi

    # Get DB name from config
    local CONFIG_PATH="${BOT_DIR}/config.php"
    local DB_NAME=$(grep '^\$dbname' "$CONFIG_PATH" | awk -F"'" '{print $2}')

    # Drop database
    if [ -n "$DB_NAME" ]; then
        ROOT_PASSWORD=$(cat /root/confmit/dbrootmit.txt | grep '$pass' | cut -d"'" -f2)
        ROOT_USER=$(cat /root/confmit/dbrootmit.txt | grep '$user' | cut -d"'" -f2)
        mysql -u "$ROOT_USER" -p"$ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" 2>/dev/null && {
            echo -e "\e[92mDatabase '$DB_NAME' removed.\033[0m"
        } || {
            echo -e "\e[93mWarning: Could not drop database '$DB_NAME'.\033[0m"
        }
    fi

    # Remove directory
    sudo rm -rf "$BOT_DIR" && echo -e "\e[92mBot directory removed: $BOT_DIR\033[0m"

    # Disable Apache site
    sudo a2dissite "addbot_${BOT_NAME}.conf" 2>/dev/null
    sudo rm -f "/etc/apache2/sites-available/addbot_${BOT_NAME}.conf"
    sudo systemctl reload apache2 2>/dev/null

    echo -e "\e[92mAdditional bot '$BOT_NAME' removed successfully.\033[0m"
}

# Export Additional Bot Database
function export_additional_bot_database() {
    echo -e "\033[32mExporting Additional Bot Database...\033[0m\n"

    # List additional bots
    local addbots=()
    for dir in /var/www/html/addbot_*; do
        if [ -d "$dir" ] && [ -f "$dir/config.php" ]; then
            addbots+=("$dir")
        fi
    done

    if [ ${#addbots[@]} -eq 0 ]; then
        echo -e "\e[91mError: No additional bots found.\033[0m"
        return 1
    fi

    echo -e "\e[36mAvailable additional bots:\033[0m"
    for i in "${!addbots[@]}"; do
        echo -e "\e[33m$((i+1)))\033[0m $(basename "${addbots[$i]}")"
    done
    echo ""
    read -p "Select bot to export [1-${#addbots[@]}]: " choice
    if [[ "$choice" -lt 1 || "$choice" -gt ${#addbots[@]} ]]; then
        echo -e "\e[91mInvalid selection.\033[0m"
        return 1
    fi

    local BOT_DIR="${addbots[$((choice-1))]}"
    local CONFIG_PATH="${BOT_DIR}/config.php"

    local DB_USER=$(grep '^\$usernamedb' "$CONFIG_PATH" | awk -F"'" '{print $2}')
    local DB_PASS=$(grep '^\$passworddb' "$CONFIG_PATH" | awk -F"'" '{print $2}')
    local DB_NAME=$(grep '^\$dbname' "$CONFIG_PATH" | awk -F"'" '{print $2}')

    if [ -z "$DB_USER" ] || [ -z "$DB_PASS" ] || [ -z "$DB_NAME" ]; then
        echo -e "\033[31m[ERROR]\033[0m Could not extract database credentials from config.php."
        return 1
    fi

    BACKUP_FILE="/root/${DB_NAME}_backup.sql"
    echo -e "\033[33mCreating backup at $BACKUP_FILE...\033[0m"

    if ! mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$BACKUP_FILE"; then
        echo -e "\033[31m[ERROR]\033[0m Failed to create database backup."
        return 1
    fi

    echo -e "\033[32mBackup successfully created at $BACKUP_FILE.\033[0m"
}

# Import Additional Bot Database
function import_additional_bot_database() {
    echo -e "\033[32mImporting Additional Bot Database...\033[0m\n"

    # List additional bots
    local addbots=()
    for dir in /var/www/html/addbot_*; do
        if [ -d "$dir" ] && [ -f "$dir/config.php" ]; then
            addbots+=("$dir")
        fi
    done

    if [ ${#addbots[@]} -eq 0 ]; then
        echo -e "\e[91mError: No additional bots found.\033[0m"
        return 1
    fi

    echo -e "\e[36mAvailable additional bots:\033[0m"
    for i in "${!addbots[@]}"; do
        echo -e "\e[33m$((i+1)))\033[0m $(basename "${addbots[$i]}")"
    done
    echo ""
    read -p "Select bot to import for [1-${#addbots[@]}]: " choice
    if [[ "$choice" -lt 1 || "$choice" -gt ${#addbots[@]} ]]; then
        echo -e "\e[91mInvalid selection.\033[0m"
        return 1
    fi

    local BOT_DIR="${addbots[$((choice-1))]}"
    local CONFIG_PATH="${BOT_DIR}/config.php"

    local DB_USER=$(grep '^\$usernamedb' "$CONFIG_PATH" | awk -F"'" '{print $2}')
    local DB_PASS=$(grep '^\$passworddb' "$CONFIG_PATH" | awk -F"'" '{print $2}')
    local DB_NAME=$(grep '^\$dbname' "$CONFIG_PATH" | awk -F"'" '{print $2}')

    if [ -z "$DB_USER" ] || [ -z "$DB_PASS" ] || [ -z "$DB_NAME" ]; then
        echo -e "\033[31m[ERROR]\033[0m Could not extract database credentials."
        return 1
    fi

    # List .sql files in /root
    echo -e "\033[36mAvailable backup files in /root:\033[0m"
    local sqlfiles=()
    for f in /root/*_backup.sql; do
        if [ -f "$f" ]; then
            sqlfiles+=("$f")
        fi
    done

    if [ ${#sqlfiles[@]} -eq 0 ]; then
        echo -e "\e[91mNo .sql backup files found in /root.\033[0m"
        return 1
    fi

    for i in "${!sqlfiles[@]}"; do
        echo -e "\e[33m$((i+1)))\033[0m $(basename "${sqlfiles[$i]}")"
    done
    echo ""
    read -p "Select backup file [1-${#sqlfiles[@]}]: " fchoice
    if [[ "$fchoice" -lt 1 || "$fchoice" -gt ${#sqlfiles[@]} ]]; then
        echo -e "\e[91mInvalid selection.\033[0m"
        return 1
    fi

    local BACKUP_FILE="${sqlfiles[$((fchoice-1))]}"

    echo -e "\033[33mImporting backup from $BACKUP_FILE...\033[0m"

    if ! mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$BACKUP_FILE"; then
        echo -e "\033[31m[ERROR]\033[0m Failed to import database."
        return 1
    fi

    echo -e "\033[32mDatabase successfully imported from $BACKUP_FILE.\033[0m"
}

# Configure Automated Backup for Additional Bot
function configure_backup_additional_bot() {
    echo -e "\033[36mConfigure Automated Backup for Additional Bot\033[0m\n"

    # List additional bots
    local addbots=()
    for dir in /var/www/html/addbot_*; do
        if [ -d "$dir" ] && [ -f "$dir/config.php" ]; then
            addbots+=("$dir")
        fi
    done

    if [ ${#addbots[@]} -eq 0 ]; then
        echo -e "\e[91mError: No additional bots found.\033[0m"
        return 1
    fi

    echo -e "\e[36mAvailable additional bots:\033[0m"
    for i in "${!addbots[@]}"; do
        echo -e "\e[33m$((i+1)))\033[0m $(basename "${addbots[$i]}")"
    done
    echo ""
    read -p "Select bot to configure backup for [1-${#addbots[@]}]: " choice
    if [[ "$choice" -lt 1 || "$choice" -gt ${#addbots[@]} ]]; then
        echo -e "\e[91mInvalid selection.\033[0m"
        return 1
    fi

    local BOT_DIR="${addbots[$((choice-1))]}"
    local BOT_NAME=$(basename "$BOT_DIR")
    local CONFIG_PATH="${BOT_DIR}/config.php"

    local DB_USER=$(grep '^\$usernamedb' "$CONFIG_PATH" | awk -F"'" '{print $2}')
    local DB_PASS=$(grep '^\$passworddb' "$CONFIG_PATH" | awk -F"'" '{print $2}')
    local DB_NAME=$(grep '^\$dbname' "$CONFIG_PATH" | awk -F"'" '{print $2}')
    local TELEGRAM_TOKEN=$(grep '^\$APIKEY' "$CONFIG_PATH" | awk -F"'" '{print $2}')
    local TELEGRAM_CHAT_ID=$(grep '^\$adminnumber' "$CONFIG_PATH" | awk -F"'" '{print $2}')

    if [ -z "$DB_USER" ] || [ -z "$DB_PASS" ] || [ -z "$DB_NAME" ] || [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        echo -e "\033[31m[ERROR]\033[0m Could not extract required credentials."
        return 1
    fi

    local BACKUP_SCRIPT="/root/addbot_backup_${BOT_NAME}.sh"

    if check_marzban_installed; then
        MYSQL_CONTAINER=$(docker ps -q --filter "name=mysql" --no-trunc)
        if [ -z "$MYSQL_CONTAINER" ]; then
            echo -e "\033[31m[ERROR]\033[0m No running MySQL container found."
            return 1
        fi
        cat <<EOF > "$BACKUP_SCRIPT"
#!/bin/bash
BACKUP_FILE="/root/${DB_NAME}_\$(date +\"%Y%m%d_%H%M%S\").sql"
docker exec $MYSQL_CONTAINER mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "\$BACKUP_FILE"
if [ \$? -eq 0 ]; then
    curl -F document=@"\$BACKUP_FILE" "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_CHAT_ID"
    rm "\$BACKUP_FILE"
else
    echo "Failed to create backup for $BOT_NAME."
fi
EOF
    else
        cat <<EOF > "$BACKUP_SCRIPT"
#!/bin/bash
BACKUP_FILE="/root/${DB_NAME}_\$(date +\"%Y%m%d_%H%M%S\").sql"
mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "\$BACKUP_FILE"
if [ \$? -eq 0 ]; then
    curl -F document=@"\$BACKUP_FILE" "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" -F chat_id="$TELEGRAM_CHAT_ID"
    rm "\$BACKUP_FILE"
else
    echo "Failed to create backup for $BOT_NAME."
fi
EOF
    fi

    chmod +x "$BACKUP_SCRIPT"

    # Show backup frequency options
    local CURRENT_CRON=$(crontab -l 2>/dev/null | grep "$BACKUP_SCRIPT" | grep -v "^#")
    if [ -n "$CURRENT_CRON" ]; then
        SCHEDULE=$(translate_cron "$CURRENT_CRON")
        echo -e "\033[33mCurrent Backup Schedule:\033[0m $SCHEDULE"
    else
        echo -e "\033[33mNo active backup schedule found.\033[0m"
    fi

    echo -e "\033[36m1) Every Minute\033[0m"
    echo -e "\033[36m2) Every Hour\033[0m"
    echo -e "\033[36m3) Every Day\033[0m"
    echo -e "\033[36m4) Every Week\033[0m"
    echo -e "\033[36m5) Disable Backup\033[0m"
    echo -e "\033[36m6) Back to Menu\033[0m"
    echo ""
    read -p "Select an option [1-6]: " backup_option

    update_cron() {
        local cron_line="$1"
        if [ -n "$CURRENT_CRON" ]; then
            crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT" | crontab - 2>/dev/null
        fi
        if [ -n "$cron_line" ]; then
            (crontab -l 2>/dev/null; echo "$cron_line") | crontab - && {
                echo -e "\033[92mBackup scheduled: $(translate_cron "$cron_line")\033[0m"
                bash "$BACKUP_SCRIPT" &>/dev/null &
            } || {
                echo -e "\033[31mFailed to schedule backup.\033[0m"
            }
        fi
    }

    case $backup_option in
        1) update_cron "* * * * * bash $BACKUP_SCRIPT" ;;
        2) update_cron "0 * * * * bash $BACKUP_SCRIPT" ;;
        3) update_cron "0 0 * * * bash $BACKUP_SCRIPT" ;;
        4) update_cron "0 0 * * 0 bash $BACKUP_SCRIPT" ;;
        5)
            if [ -n "$CURRENT_CRON" ]; then
                crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT" | crontab - && {
                    echo -e "\033[92mAutomated backup disabled.\033[0m"
                } || {
                    echo -e "\033[31mFailed to disable backup.\033[0m"
                }
            else
                echo -e "\033[93mNo backup schedule to disable.\033[0m"
            fi
            ;;
        6) manage_additional_bots ;;
        *)
            echo -e "\033[31mInvalid option. Please try again.\033[0m"
            configure_backup_additional_bot
            ;;
    esac
}

# Main Execution
process_arguments() {
    local version=""
    case "$1" in
        -v*)
            version="${1#-v}"
            if [ -n "$version" ]; then
                install_bot "-v" "$version"
            else
                if [ -n "$2" ]; then
                    install_bot "-v" "$2"
                else
                    echo -e "\033[31m[ERROR]\033[0m Please specify a version with -v (e.g., -v 4.11.1)"
                    exit 1
                fi
            fi
            ;;
        -beta)
            install_bot "-beta"
            ;;
        --beta)
            install_bot "-beta"
            ;;
        -update)
            update_bot "$2" # Pass along any arguments to update_bot, like -beta
            ;;
        *)
            show_menu
            ;;
    esac
}

process_arguments "$1" "$2"
