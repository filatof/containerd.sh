#!/bin/bash
set -e

# Установка архитектуры (по умолчанию arm64)
ARCH="${ARCH:-arm64}"

# Проверка архитектуры
if [[ ! "$ARCH" =~ ^(amd64|arm64)$ ]]; then
  echo "Неверная архитектура. Допустимые значения: amd64, arm64"
  exit 1
fi

# Функция для получения последней версии из GitHub
get_latest_version() {
  curl -s "https://api.github.com/repos/$1/releases/latest" | 
  grep '"tag_name":' | 
  sed -E 's/.*"([^"]+)".*/\1/'
}

# Установка зависимостей
sudo apt-get update
sudo apt-get install -y tar curl jq

# Определяем последние версии
echo "### Получаем информацию о последних версиях ###"
CONTAINERD_VERSION=$(get_latest_version "containerd/containerd" | sed 's/v//')
RUNC_VERSION=$(get_latest_version "opencontainers/runc" | sed 's/v//')
CNI_VERSION=$(get_latest_version "containernetworking/plugins" | sed 's/v//')

# Установка containerd
echo "### Устанавливаем containerd v$CONTAINERD_VERSION ###"
CONTAINERD_TAR="containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"
curl -LO "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/${CONTAINERD_TAR}"
sudo tar Cxzvf /usr/local "$CONTAINERD_TAR"
rm -f "$CONTAINERD_TAR"

# Настройка systemd service
echo "### Настраиваем сервис containerd ###"
curl -s https://raw.githubusercontent.com/containerd/containerd/main/containerd.service | 
  sed 's/^ExecStartPre=-\/sbin\/modprobe overlay/# &/' | 
  sudo tee /usr/lib/systemd/system/containerd.service >/dev/null

sudo systemctl daemon-reload
sudo systemctl enable --now containerd

# Установка runc
echo "### Устанавливаем runc v$RUNC_VERSION ###"
RUNC_BIN="runc.${ARCH}"
curl -LO "https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/${RUNC_BIN}"
sudo install -m 755 "$RUNC_BIN" /usr/local/sbin/runc
rm -f "$RUNC_BIN"

# Установка CNI плагинов
echo "### Устанавливаем CNI plugins v$CNI_VERSION ###"
CNI_TAR="cni-plugins-linux-${ARCH}-v${CNI_VERSION}.tgz"
curl -LO "https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/${CNI_TAR}"
sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin "$CNI_TAR"
rm -f "$CNI_TAR"

# Проверка установки
echo -e "\n### Установка завершена ###"
echo "Версии компонентов:"
containerd --version
runc --version
echo "CNI плагины установлены в /opt/cni/bin:"
ls /opt/cni/bin

# Статус сервиса
echo -e "\nСтатус containerd:"
sudo systemctl status containerd --no-pager
