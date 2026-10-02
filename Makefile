LOGIN    = egaudich
DATA_DIR = /home/$(LOGIN)/data
COMPOSE  = docker compose -f srcs/docker-compose.yml

all: up

up: dirs
	$(COMPOSE) up -d --build

dirs:
	mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

clean: down
	docker system prune -af

fclean:
	$(COMPOSE) down -v --rmi all
	docker system prune -af
	sudo rm -rf $(DATA_DIR)

re: fclean all

.PHONY: all up dirs down stop start logs ps clean fclean re