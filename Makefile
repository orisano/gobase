SHELL := PATH=$(PWD)/tools/bin:$(PATH) $(SHELL)

.PHONY: default
default: build

.PHONY: bootstrap
## setup required command line tools for make
bootstrap:
	GO111MODULE=off go get github.com/Songmu/make2help/cmd/make2help

.PHONY: gen
## run go generate
gen:
	go generate ./...

.PHONY: build
## build application (default)
build: gen
	go build -o bin/app .

.PHONY: docker-build
## build docker image
docker-build: Dockerfile
	DOCKER_BUILDKIT=1 docker build .

.PHONY: compose-test
## run test on docker-compose
compose-test: docker-compose.yaml
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker-compose up --exit-code-from api --abort-on-container-exit --build

.PHONY: help
## show help
help:
	@make2help $(MAKEFILE_LIST)
