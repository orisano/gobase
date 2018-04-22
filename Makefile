PROJECT := project
NAME := name
VERSION := 0.0.0
REVISION := $(shell git rev-parse --short HEAD)

SRCS := $(shell find . -type d -name vendor -prune -o -type f -name '*.go')
LDFLAGS := -w -X 'main.Version=$(VERSION)' -X 'main.Revision=$(REVISION)'

build: $(SRCS) vendor cli
	go generate
	go build -ldflags="$(LDFLAGS)" -o bin/$(NAME)

static-build: $(SRCS) vendor cli
	go generate
	CGO_ENABLED=0 go build -a -tags netgo -installsuffix netgo -ldflags="$(LDFLAGS) -extldflags '-static'" -o bin/$(NAME)

docker-build: Dockerfile Gopkg.toml Gopkg.lock
	docker build -t $(PROJECT)/$(NAME):$(VERSION) .

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

vendor: Gopkg.toml Gopkg.lock
	dep ensure -vendor-only

Gopkg.toml:
	dep init

Gopkg.lock: Gopkg.toml
	dep ensure -no-vendor

Dockerfile: Dockerfile.tmpl
	NAME=$(NAME) sh $< > $@

.PHONEY: build static-build docker-build test test/small test/medium test/large clean tag

.cli.deps: Gopkg.toml
	depinst -make > $@

include .cli.deps
