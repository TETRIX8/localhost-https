#!/bin/bash

# --- Цвета ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Функция для вывода сообщений ---
log_info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# --- Красивый баннер при запуске ---
clear
echo -e "${PURPLE}"
echo "        (\_._/)     "
echo "        ( o o )     ${CYAN}AkProject${NC}"
echo -e "${PURPLE}        (> ^ <)     ${YELLOW}Запуск скрипта...${NC}"
echo ""

# Анимация точек
for i in {1..3}; do
    echo -ne "${BLUE}Загрузка"
    for j in $(seq 1 $i); do
        echo -ne "."
    done
    echo -ne "\r"
    sleep 0.5
done
echo -e "${GREEN}Готово!${NC}"
echo ""

# --- Проверка, что скрипт запущен с правами sudo ---
if [ "$EUID" -ne 0 ]; then
  log_warning "Пожалуйста, запустите этот скрипт с правами sudo:"
  echo "sudo ./setup_server.sh"
  exit 1
fi

# --- Шаг 1: Сбор информации от пользователя ---
log_info "Начинаем настройку сервера. Пожалуйста, ответьте на несколько вопросов."

read -p "Введите ваше доменное имя от DuckDNS (например, tetrixuno.duckdns.org): " DOMAIN
if [ -z "$DOMAIN" ]; then
    log_warning "Доменное имя не может быть пустым. Выход."
    exit 1
fi

read -p "Введите порт, на котором запущено ваше приложение (например, 5000): " APP_PORT
if [ -z "$APP_PORT" ]; then
    log_warning "Порт не может быть пустым. Выход."
    exit 1
fi

read -p "Введите email для уведомлений от Let's Encrypt: " EMAIL

# --- Шаг 2: Установка необходимого ПО ---
log_info "Обновляем список пакетов..."
apt-get update -y

log_info "Устанавливаем Nginx..."
apt-get install nginx -y

# --- Шаг 3: Настройка Nginx ---
log_info "Создаем конфигурационный файл для вашего домена: $DOMAIN"
CONFIG_FILE="/etc/nginx/sites-available/$DOMAIN"

cat > $CONFIG_FILE <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

log_info "Активируем конфигурацию..."
ln -s $CONFIG_FILE /etc/nginx/sites-enabled/

log_info "Проверяем синтаксис Nginx..."
nginx -t

log_info "Перезапускаем Nginx..."
systemctl restart nginx

# --- Шаг 4: Установка и настройка Certbot ---
log_info "Устанавливаем Certbot через snap (самый надежный способ)..."
apt-get remove certbot -y &>/dev/null
if ! command -v snap &> /dev/null; then
    apt-get install snapd -y
fi
snap install core; snap refresh core
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot

# --- Шаг 5: Получение SSL-сертификата ---
log_info "Запускаем Certbot для получения SSL-сертификата..."
log_warning "Сейчас Certbot задаст вам несколько вопросов. Рекомендуется ответить 'Y' (Да) и выбрать опцию '2' (Redirect)."

certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL --redirect

# --- Финальное сообщение ---
log_success "================================================================="
log_success "Настройка сервера успешно завершена!"
log_success "Ваше приложение теперь доступно по безопасному адресу:"
echo -e "${YELLOW}https://"$DOMAIN"${NC}"
log_success "================================================================="
echo ""
