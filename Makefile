PROJECT := project
NAME := name
VERSION := 0.0.0
TAG := $(PROJECT)/$(NAME):$(VERSION)
REVISION = $(shell git rev-parse --short HEAD 2>/dev/null)
GO_LDFLAGS += -X 'main.Version=$(VERSION)' -X 'main.Revision=$(REVISION)'
DOCKER_BUILD_OPTS += -t $(TAG)

SRCS := $(shell git ls-files '*.go')

export PATH := $(PWD)/bin:$(PATH)

.PHONY: default
default: build

.PHONY: bootstrap
bootstrap:
	go get -u golang.org/x/tools/cmd/goimports
	go get -u github.com/golang/dep/cmd/dep
	go get -u github.com/orisano/depinst

.PHONY: init
init: bootstrap
	dep init

.PHONY: world
world: init
	rm -rf .git
	git init

.PHONY: prebuild
prebuild: vendor
	go build -i ./vendor/...

.PHONY: build
build: $(SRCS) vendor cli
	go generate ./...
	go build -ldflags="$(GO_LDFLAGS)" -o bin/$(NAME)

.PHONY: docker-build
docker-build: Dockerfile
	docker build $(DOCKER_BUILD_OPTS) .

.PHONY: docker-run
docker-run:
	docker run $(TAG)

.PHONY: compose-test
compose-test: docker-compose.yaml
	docker-compose up --exit-code-from api --abort-on-container-exit --build

.PHONY: test
test: test/small

.PHONY: test/small
test/small:
	go test -v -run='^Test([^M][^_]|[^L][^_])' ./...

.PHONY: test/medium
test/medium:
	go test -v -run='^TestM_' ./...

.PHONY: test/large
test/large:
	go test -v -run='^TestL_' ./...

.PHONY: clean
clean:
	rm -rf bin vendor

.PHONY: tag
tag:
	git tag $(VERSION)

.PHONY: fmt
fmt:
	goimports -w $(SRCS)

vendor: Gopkg.toml Gopkg.lock
	dep ensure -vendor-only

Gopkg.lock: Gopkg.toml
	dep ensure -no-vendor

Dockerfile: Dockerfile.tmpl
	PKG_PATH=$(subst $(shell go env GOPATH)/src/,,$(PWD)) NAME=$(NAME) sh $< > $@

docker-compose.yaml: Dockerfile

.cli.deps: Gopkg.toml
	depinst -make > $@

ifeq (,$(findstring $(MAKECMDGOALS),bootstrap init world))
-include .cli.deps
endif
