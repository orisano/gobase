PROJECT := project
NAME := name
VERSION := 0.0.0
REVISION = $(shell git rev-parse --short HEAD 2>/dev/null)
GO_LDFLAGS += -X 'main.Version=$(VERSION)' -X 'main.Revision=$(REVISION)'

SRCS := $(shell git ls-files '*.go')

export PATH := $(PWD)/bin:$(PATH)

default: build

bootstrap:
	go get -u golang.org/x/tools/cmd/goimports
	go get -u github.com/golang/dep/cmd/dep
	go get -u github.com/orisano/depinst

init: bootstrap
	dep init

world: init
	rm -rf .git
	git init

prebuild: vendor
	go build -i ./vendor/...

build: $(SRCS) vendor cli
	go generate ./...
	go build -ldflags="$(GO_LDFLAGS)" -o bin/$(NAME)

docker-build: Dockerfile Gopkg.toml Gopkg.lock
	docker build -t $(PROJECT)/$(NAME):$(VERSION) .

docker-run:
	docker run $(PROJECT)/$(NAME):$(VERSION)

compose-test:
	docker-compose up --exit-code-from api --abort-on-container-exit --build

test test/small:
	go test -v -run='^Test([^M][^_]|[^L][^_])' ./...

test/medium:
	go test -v -run='^TestM_' ./...

test/large:
	go test -v -run='^TestL_' ./...

clean:
	rm -rf bin vendor

tag:
	git tag $(VERSION)

fmt:
	goimports -w $(SRCS)

vendor: Gopkg.toml Gopkg.lock
	dep ensure -vendor-only

Gopkg.lock: Gopkg.toml
	dep ensure -no-vendor

Dockerfile: Dockerfile.tmpl
	DIR=$(subst $(shell go env GOPATH)/src/,,$(PWD)) NAME=$(NAME) sh $< > $@

.PHONEY: default bootstrap init world prebuild build docker-build docker-run compose-test test test/small test/medium test/large clean tag fmt

.cli.deps: Gopkg.toml
	depinst -make > $@

ifeq (,$(findstring $(MAKECMDGOALS),init world bootstrap))
-include .cli.deps
endif
