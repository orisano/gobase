PROJECT := project
NAME := name
TAG := $(PROJECT)/$(NAME)
DOCKER_BUILD_OPTS += -t $(TAG)

SRCS := $(shell find . -type d -name vendor -prune -o -type f -name '*.go' -print)

export PATH := $(PWD)/bin:$(PATH)

.PHONY: default
default: build

.PHONY: bootstrap
## setup required command line tools for make
bootstrap:
	go get -u golang.org/x/tools/cmd/goimports
	go get -u github.com/golang/dep/cmd/dep
	go get -u github.com/orisano/depinst
	go get -u github.com/Songmu/make2help/cmd/make2help

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

.PHONY: prebuild
## prebuild vendored libraries (for speedup of build)
prebuild: vendor
	go build -i ./vendor/...

.PHONY: build
## build application (default)
build: $(SRCS) vendor cli
	go generate ./...
	go build -ldflags="$(GO_LDFLAGS)" -o bin/$(NAME)

.PHONY: docker-build
## build docker image
docker-build: Dockerfile
	docker build $(DOCKER_BUILD_OPTS) .

.PHONY: docker-run
## run docker image
docker-run:
	docker run $(TAG)

.PHONY: compose-test
## run test on docker-compose
compose-test: docker-compose.yaml
	docker-compose up --exit-code-from api --abort-on-container-exit --build

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

.PHONY: clean
## clean in the directory
clean:
	rm -rf bin vendor

.PHONY: fmt
## format source code
fmt:
	goimports -w $(SRCS)

.PHONY: help
## show help
help:
	@make2help $(MAKEFILE_LIST)

vendor: Gopkg.lock
	dep ensure -vendor-only

Gopkg.lock: Gopkg.toml .imports.txt
	dep ensure -no-vendor

.imports.txt: $(SRCS)
	@go list -f '{{ join .Imports "\n" }}' ./... > $@

Dockerfile: Dockerfile.tmpl
	@PKG_PATH=$(subst $(shell go env GOPATH)/src/,,$(PWD)) NAME=$(NAME) sh $< > $@

docker-compose.yaml: Dockerfile

cli.mk: Gopkg.toml
	@depinst -make > $@

Gopkg.toml:
	@echo error: Gopkg.toml not found. please run \"make init\" or \"make world\"
	@exit 1

ifeq (,$(findstring $(MAKECMDGOALS),bootstrap init world))
-include cli.mk
endif
