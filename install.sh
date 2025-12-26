RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() {
	echo -e "${GREEN}[SUCCESS] $1${NC}"
}

print_error() {
	echo -e "${RED}[ERROR] $1${NC}"
}

print_info() {
	echo -e "${BLUE}[INFO] $1${NC}"
}

print_warning() {
	echo -e "${YELLOW}[WARNING] $1${NC}"
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
	apt install software-properties-common -y
	apt install net-tools zip unzip nginx libnginx-mod-stream -y
}

setup_nginx() {
	print_info "Setup nginx..."
	sleep 1

	# Matikam nginx & hapus konfigurasi bawaan
	systemctl stop nginx
	rm -rf /etc/nginx/*

	# Download konfigurasi custom
	curl -sS "${GITHUB_RAW}/etc/nginx/conf.zip" -o /tmp/nginx_conf.zip
	if [[ ! -s "/tmp/nginx_conf.zip" ]]; then
		print_error "Download kofigurasi nginx gagal"
		exit 1
	fi

	print_info "Extracting nginx config..."
	unzip -qo /tmp/nginx_conf.zip -d /etc/nginx/
	rm -rf /tmp/nginx_conf.zip

	# Symlink modules
	mkdir -p /etc/nginx/modules-enabled
	ln -sf /usr/share/nginx/modules-available/mod-stream.conf /etc/nginx/modules-enabled/50-mod-stream.conf

	# Cloudflare real ip
	echo "# Cloudflare Real IP" >/etc/nginx/conf.d/yixian.conf
	for ip in $(curl -s https://www.cloudflare.com/ips-v4); do
		echo "set_real_ip_from $ip;" >>/etc/nginx/conf.d/yixian.conf
	done
	for ip in $(curl -s https://www.cloudflare.com/ips-v6); do
		echo "set_real_ip_from $ip;" >>/etc/nginx/conf.d/yixian.conf
	done
	echo "real_ip_header X-Forwarded-For;" >>/etc/nginx/conf.d/yixian.conf
	echo "real_ip_recursive on;" >>/etc/nginx/conf.d/yixian.conf

	# Set user & permission
	chown -R root:root /etc/nginx
	chmod -R 755 /etc/nginx

	if nginx -t >/dev/null 2>&1; then
		systemctl restart nginx
		print_success "Instalasi nginx success"
	else
		print_error "Konfigurasi nginx error"
		nginx -t
		exit 1
	fi
}

setup_dropbear() {
	print_info "Setup dropbear..."
	sleep 1

	# Install & stop dripbear bawaan
	apt install dropbear -y
	systemctl stop dropbear

	# Download binary dropbear 2019 (by default)
	curl -sS "${GITHUB_RAW}/usr/sbin/dropbear/dropbear-2019" -o /usr/sbin/dropbear
	if [[ ! -s "/usr/sbin/dropbear" ]]; then
		print_error "Gagal download binary dropbear"
		apt install --reinstall dropbear -y
	else
		chmod +x /usr/sbin/dropbear
		print_success "Dropbear installed successfully"
	fi

	curl -sS "${GITHUB_RAW}/etc/default/dropbear" -o /etc/default/dropbear
	curl -sS "${GITHUB_RAW}/etc/issue.net" -o /etc/issue.net
	systemctl restart dropbear

	# Validasi port dropbear
	if netstat -tunlp | grep :90 >/dev/null; then
		print_success "Dropbear running (sesuai config file)"
	else
		print_error "Dropbear gagal start"
		exit 1
	fi
}

setup_wsepro() {
	print_info "Setup WS-ePro..."
	sleep 1

	curl -sS "${GITHUB_RAW}/usr/sbin/ws-epro" -o /usr/sbin/ws-epro
	chmod +x /usr/sbin/ws-epro

	curl -sS "${GITHUB_RAW}/usr/sbin/tunws.conf" -o /usr/sbin/tunws.conf
	curl -sS "${GITHUB_RAW}/etc/systemd/system/tunws.service" -o /etc/systemd/system/tunws.service

	systemctl daemon-reload
	systemctl enable tunws
	systemctl restart tunws

	if netstat -tunlp | grep :1230 >/dev/null; then
		print_success "WS ePro berjalan di port 1230"
	else
		print_error "WS ePro gagal berjalan"
		exit 1
	fi
}

main() {
	check_internet
	check_root
	check_virt
	check_os
	setup_dependencies
	setup_nginx
	setup_dropbear
	setup_wsepro
}

main "$@"
