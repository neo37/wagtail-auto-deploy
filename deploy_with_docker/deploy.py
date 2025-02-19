import os
import subprocess
from jinja2 import Environment, FileSystemLoader
from dotenv import load_dotenv

# Загрузка переменных окружения
load_dotenv()

# Переменные окружения
config_data = {
    "domain": os.getenv("DOMAIN"),
    "postgres_user": os.getenv("POSTGRES_USER"),
    "postgres_password": os.getenv("POSTGRES_PASSWORD"),
    "postgres_db": os.getenv("POSTGRES_DB"),
}

# Настройка Jinja
env = Environment(loader=FileSystemLoader("templates"))

# Файлы для рендеринга
templates = [
    ("nginx.conf.j2", "configs/nginx.conf"),
    ("docker-compose.yml.j2", "configs/docker-compose.yml"),
]

os.makedirs("configs", exist_ok=True)

for template_name, output_path in templates:
    template = env.get_template(template_name)
    rendered_content = template.render(config_data)
    with open(output_path, "w") as f:
        f.write(rendered_content)
    print(f"Создан файл: {output_path}")




for template_name, output_path in templates:
    template = env.get_template(template_name)
    rendered_content = template.render(config_data)
    with open(output_path, "w") as f:
        f.write(rendered_content)
    print(f"Создан файл: {output_path}")

print("Конфигурационные файлы успешно сгенерированы!")

# Файл nginx.conf.j2
nginx_template = os.getenv('nginx.conf.j2')
