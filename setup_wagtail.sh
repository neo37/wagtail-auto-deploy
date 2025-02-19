#!/bin/bash

# Чтение переменных окружения
REMOTE_IP="${REMOTE_IP:-}"
REMOTE_USER="${REMOTE_USER:-}"
REMOTE_PASS="${REMOTE_PASS:-}"

if [[ -z "$REMOTE_IP" || -z "$REMOTE_USER" || -z "$REMOTE_PASS" ]]; then
    echo "Пожалуйста, установите переменные окружения REMOTE_IP, REMOTE_USER и REMOTE_PASS."
    exit 1
fi

# Проверка наличия sshpass
if ! command -v sshpass &> /dev/null; then
    echo "Устанавливаю sshpass..."
    sudo apt update
    sudo apt install sshpass -y
fi

NEW_USER="myuser"
PROJECT_DIR="/home/${NEW_USER}/wagtail_project"
STATIC_ROOT="${PROJECT_DIR}/mysite/static/"
MEDIA_ROOT="${PROJECT_DIR}/mysite/media/"

# Создаём локально конфиг Nginx
mkdir -p ./nginx_configs
cat > ./nginx_configs/wagtail <<EOF
server {
    listen 80;
    server_name ${REMOTE_IP};

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /static/ {
        alias ${STATIC_ROOT};
    }

    location /media/ {
        alias ${MEDIA_ROOT};
    }

    access_log /var/log/nginx/wagtail_access.log;
    error_log /var/log/nginx/wagtail_error.log;
}
EOF

echo "Конфиг Nginx создан локально (./nginx_configs/wagtail)."
echo "Проверьте файл и при необходимости отредактируйте."
read -p "Нажмите Enter для продолжения..."

# Создание пользователя на сервере
USER_CREATION_COMMANDS=$(cat <<EOF
set -e
if id "${NEW_USER}" &>/dev/null; then
    echo "Пользователь ${NEW_USER} уже существует, пропускаю создание."
else
    echo "Создаю пользователя ${NEW_USER}..."
    sudo adduser --disabled-password --gecos "" ${NEW_USER}
    sudo usermod -aG sudo ${NEW_USER}
    echo "Пользователь ${NEW_USER} создан."
fi
EOF
)

sshpass -p "$REMOTE_PASS" ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" "$USER_CREATION_COMMANDS"

# Копирование локального конфига Nginx на сервер
sshpass -p "$REMOTE_PASS" scp -o StrictHostKeyChecking=no ./nginx_configs/wagtail ${REMOTE_USER}@${REMOTE_IP}:/tmp/wagtail_nginx_conf

# Основные команды настройки и развертывания
REMOTE_COMMANDS=$(cat <<EOF
set -e

echo "Обновление и установка зависимостей..."
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-venv git nginx ufw postgresql postgresql-contrib gunicorn

echo "Настройка базы данных PostgreSQL..."
sudo -u postgres psql -c "DROP DATABASE IF EXISTS wagtail_db;"
sudo -u postgres psql -c "DROP USER IF EXISTS wagtail_user;"
sudo -u postgres psql -c "CREATE DATABASE wagtail_db;"
sudo -u postgres psql -c "CREATE USER wagtail_user WITH PASSWORD 'yourpassword';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE wagtail_db TO wagtail_user;"

echo "Перемещение и активация Nginx конфига..."
sudo mv /tmp/wagtail_nginx_conf /etc/nginx/sites-available/wagtail
sudo rm -f /etc/nginx/sites-enabled/wagtail
sudo ln -s /etc/nginx/sites-available/wagtail /etc/nginx/sites-enabled/wagtail
sudo nginx -t
sudo systemctl restart nginx

sudo ufw allow 22

sudo ufw allow 'Nginx Full'
sudo ufw --force enable

sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

echo "Настройка проекта Wagtail под пользователем ${NEW_USER}..."
sudo -i -u ${NEW_USER} bash <<'EOSU'
set -e
mkdir -p ${PROJECT_DIR}
cd ${PROJECT_DIR}
python3 -m venv venv
source venv/bin/activate
pip install wagtail-bakery gunicorn psycopg2-binary
if [ ! -d "mysite" ]; then
    wagtail start mysite
fi
cd mysite
pip install -r requirements.txt

# Настройка settings для PostgreSQL
sed -i "s/'ENGINE': 'django.db.backends.sqlite3'/'ENGINE': 'django.db.backends.postgresql'/g" mysite/settings/base.py
sed -i "/'ENGINE'/a\\        'NAME': 'wagtail_db', 'USER': 'wagtail_user', 'PASSWORD': 'yourpassword', 'HOST': 'localhost', 'PORT': ''" mysite/settings/base.py

# Добавление ALLOWED_HOSTS
# sed -i "s/ALLOWED_HOSTS = \\[\\]/ALLOWED_HOSTS = ['127.0.0.1','${REMOTE_IP}']/" mysite/settings/base.py

# Отключение заголовка Cross-Origin-Opener-Policy
sed -i "/SECURE_CROSS_ORIGIN_OPENER_POLICY/d" mysite/settings/base.py
echo "# Отключение Cross-Origin-Opener-Policy" >> mysite/settings/base.py
echo "SECURE_CROSS_ORIGIN_OPENER_POLICY = None" >> mysite/settings/base.py

echo "DEBUG = True" >> mysite/settings/base.py
# echo "ALLOWED_HOSTS = ['*']" >> mysite/settings/base.py

echo "Применение миграций..."
python manage.py migrate

echo "Создание суперпользователя..."
echo "from django.contrib.auth.models import User; User.objects.create_superuser('admin', 'admin@example.com', 'adminpassword')" | python manage.py shell

echo "Сбор статических файлов..."
python manage.py collectstatic --noinput
mkdir -p ${MEDIA_ROOT}
EOSU

echo "Настройка прав на статические и медиа файлы..."
sudo chown -R ${NEW_USER}:www-data ${PROJECT_DIR}
sudo chmod -R 775 ${PROJECT_DIR}


echo "Запуск Gunicorn под пользователем ${NEW_USER}..."
sudo -i -u ${NEW_USER} bash <<'EOSU'


sudo chmod o+rx /home
sudo chmod o+rx /home/myuser
sudo chmod o+rx /home/myuser/wagtail_project
sudo chmod o+rx /home/myuser/wagtail_project/mysite
sudo chmod -R o+rx /home/myuser/wagtail_project/mysite/staticfiles


cd ${PROJECT_DIR}/mysite
source ../venv/bin/activate
gunicorn mysite.wsgi:application --bind 0.0.0.0:8000 &
EOSU



EOF
)

# Выполнение команд
sshpass -p "$REMOTE_PASS" ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" "$REMOTE_COMMANDS"

echo "Готово! Конфиги скопированы, пользователь создан, проект настроен и Gunicorn запущен."
echo "sudo chmod o+rx /home"
echo "sudo chmod o+rx /home/myuser"
echo "sudo chmod o+rx /home/myuser/wagtail_project"
echo "sudo chmod o+rx /home/myuser/wagtail_project/mysite"
echo "sudo chmod -R o+rx /home/myuser/wagtail_project/mysite/staticfiles"

