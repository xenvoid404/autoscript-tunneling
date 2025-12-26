RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() {
	echo -e "${GREEN}[SUCCESS] $1"
}

print_error() {
	echo -e "${RED}[ERROR] $1"
}

print_info() {
	echo -e "${BLUE}[INFO] $1"
}

print_warning() {
	echo -e "${YELLOW}[WARNING] $1"
}

# Github Configuration
GITHUB_RAW_ENDPOINT="https://raw.githubusercontent.com"
GITHUB_USERNAME="xenvoid404"
GITHUB_REPO="autoscript-tunneling"
GITHUB_REPO_BRANCH="main"
GITHUB_RAW="${GITHUB_RAW_ENDPOINT}/${GITHUB_USERNAME}/${GITHUB_REPO}/${GITHUB_REPO_BRANCH}"

check_internet() {
	print_info "Checking internet connection..."
	sleep 1

	if ping -c 1 google.com >/dev/null || ping -c 1 8.8.8.8 >/dev/null; then
		print_success "Internet connection is available"
	else
		print_error "No internet connection"
		print_info "Please make sure the server is connected to the internet to download the script"
		exit 1
	fi
}

check_root() {
	print_info "Checking user root..."
	sleep 1

	if [[ $EUID -ne 0 ]]; then
		print_error "This script must be run as root!"
		exit 1
	else
		print_success "Root privileges confirmed"
	fi
}

check_virt() {
	print_info "Checking virtualization environment..."
	sleep 1

	if [[ "$(systemd-detect-virt 2>/dev/null)" == "openvz" ]] || grep -q openvz /proc/user_beancounters; then
		print_error "Unsupported virtualization: OpenVZ detected"
		print_info "This script requires KVM/Xen or baremetal environment"
		exit 1
	else
		print_success "Virtualization check passed"
	fi
}

check_os() {
	print_info "Detecting operating system..."
	sleep 1

	if [[ -f /etc/os-release ]]; then
		. /etc/os-release
		OS=$ID
		VERSION=$VERSION_ID
		VERSION_MAJOR=$(echo "$VERSION" | cut -d'.' -f1)
	else
		print_error "Failed to detect operating system"
		exit 1
	fi

	case "$OS" in
	"ubuntu")
		if [[ "$VERSION_MAJOR" -ge 22 ]]; then
			print_success "Supported OS detected: Ubuntu $VERSION"
		else
			print_error "Unsupported Ubuntu version! Minimum required: Ubuntu 22+"
			exit 1
		fi
		;;
	"debian")
		if [[ "$VERSION_MAJOR" -ge 11 ]]; then
			print_success "Supported OS detected: Debian $VERSION"
		else
			print_error "Unsupported Debian version! Minimum required: Debian 11+"
			exit 1
		fi
		;;
	*)
		print_error "Unsupported operating system: $OS"
		print_info "This script only supports Ubuntu 22+ and Debian 11+"
		exit 1
		;;
	esac
}

setup_dependencies() {
	# Remove unnecessary packages
	apt remove --purge -y man-db apache2 ufw exim4 firewalld snapd*
	apt clean && apt autoremove -y

	# Disable IPv6
	sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
	sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1

	# Update system dan instalasi packages
	apt update && apt upgrade -y
	apt install software-properties-common -y
	apt install curl jq wget screen build-essential -y
	apt install zip unzip nginx -y
}

setup_nginx() {
  print_info "Setup nginx..."
  sleep 1
  
  systemctl stop nginx
  rm -rf /etc/nginx/*
  
  mkdir -p /tmp/nginx
  curl -sS "${GITHUB_RAW}/etc/nginx/conf.zip" -o /tmp/nginx/conf.zip
  unzip /tmp/nginx/conf.zip
  rm -rf /tmp/nginx/conf.zip
  mv /tmp/nginx/* /etc/nginx/
  chown -R root:root /etc/nginx
  chmod -R 755 /etc/nginx
  
  nginx -t && systemctl status nginx
  systemctl restart nginx
  print_success "Instalasi nginx success"
}

main() {
	check_internet
	check_root
	check_virt
	check_os
	setup_dependencies
}

main "$@"
