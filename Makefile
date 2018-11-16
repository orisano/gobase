PROJECT := project
NAME := name
TAG := $(PROJECT)/$(NAME)

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

.PHONY: gen
## run go generate
gen: cli
	PATH=$$(pwd)/bin:$$PATH go generate ./...

.PHONY: build
## build application (default)
build: gen
	go build -o bin/$(NAME)

.PHONY: docker-build
## build docker image
docker-build: Dockerfile
	DOCKER_BUILDKIT=1 docker build $(DOCKER_BUILD_OPTS) -t $(TAG) .

.PHONY: docker-run
## run docker image
docker-run:
	docker run --rm $(TAG)

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

cli.mk: Gopkg.toml
	@depinst -make > $@

cli-vendor.mk: Gopkg.toml
	@depinst -list | awk '{print "vendor/" $$0 ": vendor\n"}' > $@

Gopkg.lock: Gopkg.toml
	dep ensure -no-vendor

Gopkg.toml:
	@echo error: Gopkg.toml not found. please run \"make init\" or \"make world\"
	@exit 1

vendor: Gopkg.lock
	dep ensure -vendor-only
	@touch vendor

ifeq (,$(findstring $(MAKECMDGOALS),bootstrap init world help))
-include cli.mk
-include cli-vendor.mk
endif
