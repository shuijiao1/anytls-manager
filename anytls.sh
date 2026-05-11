#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="0.1.2"
REPO_RAW="https://raw.githubusercontent.com/shuijiao1/anytls-manager/main"
UPDATE_URL="$REPO_RAW/anytls.sh"
VERSION_URL="$REPO_RAW/version.txt"
BIN="/usr/local/bin/anytls-server"
SERVICE_FILE="/etc/systemd/system/anytls.service"
SERVICE_NAME="anytls"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
say(){ printf '%b\n' "$*"; }; ok(){ say "${GREEN}✓${NC} $*"; }; err(){ say "${RED}✖${NC} $*" >&2; }; info(){ say "${BLUE}▶${NC} $*"; }; warn(){ say "${YELLOW}⚠${NC} $*"; }
have(){ command -v "$1" >/dev/null 2>&1; }
need_root(){ [[ ${EUID:-$(id -u)} -eq 0 ]] || { err "请用 root 运行"; exit 1; }; }
install_pkg(){ if have apt-get; then apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"; elif have dnf; then dnf install -y "$@"; elif have yum; then yum install -y "$@"; else err "未找到包管理器，请手动安装：$*"; exit 1; fi; }
ensure_deps(){ local m=(); for c in curl unzip grep sed systemctl; do have "$c" || m+=("$c"); done; ((${#m[@]}==0)) || install_pkg curl unzip grep sed systemd coreutils; }
validate_port(){ [[ "$1" =~ ^[0-9]+$ ]] && ((10#$1>=1 && 10#$1<=65535)); }
rand_port(){ echo $((RANDOM % 55536 + 10000)); }
rand_pass(){ local a s1 s2 r; a=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 14 || true); s1='-/@'; r="${a}${s1:$((RANDOM%3)):1}${s1:$((RANDOM%3)):1}"; echo "$r" | grep -o . | shuf | tr -d '\n'; }
urlencode(){ local LC_ALL=C s="$1" o="" i c h; for ((i=0;i<${#s};i++)); do c=${s:i:1}; case "$c" in [a-zA-Z0-9.~_-]) o+="$c";; *) printf -v h '%%%02X' "'$c"; o+="$h";; esac; done; printf '%s' "$o"; }
urlencode_anytls_auth(){ local LC_ALL=C s="$1" o="" i c h; for ((i=0;i<${#s};i++)); do c=${s:i:1}; case "$c" in [a-zA-Z0-9.~_/-]) o+="$c";; *) printf -v h '%%%02X' "'$c"; o+="$h";; esac; done; printf '%s' "$o"; }
asset_regex(){ case "$(uname -m)" in x86_64|amd64) echo 'linux_amd64\.zip$';; *) err "暂只支持 amd64/x86_64，当前架构：$(uname -m)"; exit 1;; esac; }
latest_asset(){ local json url re; re="$(asset_regex)"; json="$(curl -fsSL https://api.github.com/repos/anytls/anytls-go/releases/latest)"; url="$(printf '%s' "$json" | grep 'browser_download_url' | cut -d '"' -f 4 | grep -E "$re" | head -n1 || true)"; [[ -n "$url" ]] || { err "未找到 amd64/x86_64 的 anytls-go Release 资产"; exit 1; }; echo "$url"; }
install_anytls(){ ensure_deps; local url tmp port password; url="$(latest_asset)"; tmp="$(mktemp -d)"; info "下载 anytls-go：$url"; curl -fL --retry 3 -o "$tmp/anytls.zip" "$url"; unzip -q -o "$tmp/anytls.zip" -d "$tmp"; local found; found=$(find "$tmp" -type f -name 'anytls-server*' | head -n1); [[ -n "$found" ]] || { err "压缩包内未找到 anytls-server"; exit 1; }; install -m 0755 "$found" "$BIN"; rm -rf "$tmp"; read -rp "请输入 anytls 监听端口（留空随机）: " port; port=${port:-$(rand_port)}; validate_port "$port" || { err "端口无效"; exit 1; }; read -rp "请输入 anytls 密码（留空随机）: " password; password=${password:-$(rand_pass)}; write_service "$port" "$password"; systemctl daemon-reload; systemctl enable --now "$SERVICE_NAME"; ok "anytls 已安装/更新并启动"; display_config "$port" "$password"; }
write_service(){ local port="$1" password="$2"; cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=AnyTLS Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
ExecStart=$BIN -l 0.0.0.0:$port -p $password
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
}
parse_port(){ grep '^ExecStart=' "$SERVICE_FILE" | sed -n 's/.*-l [^:]*:\([0-9]*\).*/\1/p'; }
parse_pass(){ grep '^ExecStart=' "$SERVICE_FILE" | sed -n 's/.* -p \([^ ]*\).*/\1/p'; }
display_config(){ local port="$1" password="$2" ip pe tag; ip=$(curl -fsS4 https://ipv4.icanhazip.com 2>/dev/null | tr -d '\n' || true); ip=${ip:-"<服务器IP>"}; pe=$(urlencode_anytls_auth "$password"); tag=$(urlencode VPS); say "------------------------------------------"; say "anytls 当前配置"; say "地址: ${GREEN}$ip${NC}"; say "端口: ${GREEN}$port${NC}"; say "密码: ${GREEN}$password${NC}"; say "------------------------------------------"; say "Surge:"; say "${GREEN}VPS = anytls, $ip, $port, password=\"$password\", skip-cert-verify=true, udp-relay=true, reuse=false${NC}"; say "Mihomo:"; say "${GREEN}  - {\"name\":\"VPS\",\"server\":\"$ip\",\"port\":$port,\"password\":\"$password\",\"skip-cert-verify\":true,\"reuse\":false,\"type\":\"anytls\"}${NC}"; say "URI:"; say "${GREEN}anytls://${pe}@${ip}:${port}?security=tls&type=tcp&allowInsecure=1&insecure=1#${tag}${NC}"; say "------------------------------------------"; }
view_config(){ [[ -f "$SERVICE_FILE" ]] || { err "anytls 未安装"; return 1; }; display_config "$(parse_port)" "$(parse_pass)"; }
modify_config(){ [[ -f "$SERVICE_FILE" ]] || { err "anytls 未安装"; return 1; }; local port password; read -rp "新端口（留空随机）: " port; port=${port:-$(rand_port)}; validate_port "$port" || { err "端口无效"; return 1; }; read -rp "新密码（留空随机）: " password; password=${password:-$(rand_pass)}; write_service "$port" "$password"; systemctl daemon-reload; systemctl restart "$SERVICE_NAME"; ok "配置已更新"; display_config "$port" "$password"; }
uninstall_anytls(){ read -rp "确认卸载 anytls？[y/N]: " y; [[ "$y" =~ ^[Yy]$ ]] || return 0; systemctl disable --now "$SERVICE_NAME" 2>/dev/null || true; rm -f "$SERVICE_FILE" "$BIN"; systemctl daemon-reload; ok "已卸载 anytls"; }
service_ctl(){ case "$1" in start|stop|restart) systemctl "$1" "$SERVICE_NAME" && ok "服务已$1";; status) systemctl --no-pager --full status "$SERVICE_NAME" || true;; esac; }
check_update(){ local r tmp; r=$(curl -fsSL "$VERSION_URL" 2>/dev/null | head -n1 | tr -cd '0-9.' || true); [[ -n "$r" && "$r" != "$VERSION" ]] || { ok "脚本已是最新 v$VERSION"; return; }; warn "发现新版脚本 v$r"; read -rp "更新？[y/N]: " y; [[ "$y" =~ ^[Yy]$ ]] || return; tmp=$(mktemp); curl -fsSL "$UPDATE_URL" -o "$tmp"; bash -n "$tmp"; install -m 0755 "$tmp" "$0"; rm -f "$tmp"; ok "脚本已更新"; exit 0; }
status_line(){ [[ -x "$BIN" ]] && printf 已安装 || printf 未安装; printf ' / '; systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null && printf 运行中 || printf 未运行; }
menu() {
  need_root
  ensure_deps
  while true; do
    clear || true
    say "${CYAN}============================================${NC}"
    say "          ${CYAN}AnyTLS-Go 管理脚本 v$VERSION${NC}"
    say "${CYAN}============================================${NC}"
    say "${GREEN}仓库: github.com/shuijiao1/anytls-manager${NC}"
    say "${GREEN}作者: shuijiao1${NC}"
    say "${CYAN}============================================${NC}"
    say "${YELLOW}服务状态：$(status_line)${NC}"
    say ""
    say "${YELLOW}=== 基础功能 ===${NC}"
    say "${GREEN}1.${NC} 安装/更新 anytls"
    say "${GREEN}2.${NC} 卸载 anytls"
    say "${GREEN}3.${NC} 修改配置"
    say "${GREEN}4.${NC} 查看配置"
    say "${GREEN}5.${NC} 重启服务"
    say ""
    say "${YELLOW}=== 服务管理 ===${NC}"
    say "${GREEN}6.${NC} 启动服务"
    say "${GREEN}7.${NC} 停止服务"
    say "${GREEN}8.${NC} 查看服务状态"
    say ""
    say "${YELLOW}=== 系统功能 ===${NC}"
    say "${GREEN}9.${NC} 检查脚本更新"
    say "${GREEN}0.${NC} 退出脚本"
    say "${CYAN}============================================${NC}"
    read -rp "请输入选项 [0-9]: " c
    case "$c" in
      1) install_anytls ;;
      2) uninstall_anytls ;;
      3) modify_config ;;
      4) view_config ;;
      5) service_ctl restart ;;
      6) service_ctl start ;;
      7) service_ctl stop ;;
      8) service_ctl status ;;
      9) check_update ;;
      0) exit 0 ;;
      *) err "无效选项" ;;
    esac
    say ""
    read -rp "按回车继续..." _
  done
}

case "${1:-}" in install) need_root; install_anytls;; config|view) need_root; view_config;; modify) need_root; modify_config;; start|stop|restart|status) need_root; service_ctl "$1";; uninstall) need_root; uninstall_anytls;; update-script) need_root; check_update;; -h|--help|help) echo "bash anytls.sh [install|modify|view|start|stop|restart|status|uninstall|update-script]";; *) menu;; esac
