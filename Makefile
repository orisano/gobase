PROJECT := project
NAME := name
TAG := $(PROJECT)/$(NAME)

export PATH := $$(pwd)/tools/bin:$(PATH)

.PHONY: default
default: build

.PHONY: bootstrap
## setup required command line tools for make
bootstrap:
	go get github.com/golang/dep/cmd/dep
	go get github.com/orisano/depinst
	go get github.com/Songmu/make2help/cmd/make2help

.PHONY: init
## initialize project
init: bootstrap
	@rm README.md
	dep init

.PHONY: world
## initialize repository
world: init
	rm -rf .git
	git init

.PHONY: gen
## run go generate
gen:
	go generate ./...

.PHONY: build
## build application (default)
build: gen
	go build -o bin/$(NAME)

.PHONY: docker-build
## build docker image
docker-build: Dockerfile
	DOCKER_BUILDKIT=1 docker build $(DOCKER_BUILD_OPTS) -t $(TAG) .

.PHONY: compose-test
## run test on docker-compose
compose-test: docker-compose.yaml
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker-compose up --exit-code-from api --abort-on-container-exit --build

.PHONY: test
## alias of test/small
test: test/small

.PHONY: test/small
## run small-test
test/small:
	go test -v -run='^Test([^M][^_]|[^L][^_])' ./...

.PHONY: test/medium
## run medium-test
test/medium:
	go test -v -run='^TestM_' ./...

.PHONY: test/large
## run large-test
test/large:
	go test -v -run='^TestL_' ./...

.PHONY: help
## show help
help:
	@make2help $(MAKEFILE_LIST)

.PHONY: pre-push
## pre push hooks
pre-push:
	dep check || dep ensure

Dockerfile: Dockerfile.tmpl
	@PKG_PATH=$(shell go list) NAME=$(NAME) sh $< > $@

docker-compose.yaml: Dockerfile

