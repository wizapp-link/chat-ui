# Makefile

# Specify the default target. This is what will be executed when you just type `make`.
.PHONY: default
default: run

# Start MongoDB using Docker
.PHONY: start-mongo
start-mongo:
	@echo "Checking for existing MongoDB container..."
	@if [ $$(docker ps -a -q -f name=mongo-chatui) ]; then \
		echo "Container exists. Checking if it's running..."; \
		if [ ! $$(docker ps -q -f name=mongo-chatui) ]; then \
			echo "Container is not running. Starting container..."; \
			docker start mongo-chatui; \
		else \
			echo "MongoDB container is already running."; \
		fi \
	else \
		echo "Container does not exist. Creating and starting a new MongoDB container..."; \
		docker run -d -p 27017:27017 --name mongo-chatui mongo:latest; \
	fi



# Run the Chat UI application. Adjust this command based on how your application is started.
.PHONY: run
run: start-mongo
	@echo "Running Chat UI..."
	@npm install
	@npm run dev

