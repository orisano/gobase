PROJECT := project
NAME := name
VERSION := 0.0.0
REVISION := $(shell git rev-parse --short HEAD)

SRCS := $(shell find . -type f -name '*.go')
LDFLAGS := -w -X 'main.Version=$(VERSION)' -X 'main.Revision=$(REVISION)'

build: $(SRCS) vendor
	go build -ldflags="$(LDFLAGS)" -o bin/$(NAME)

static-build: $(SRCS)
	go build -a -tags netgo -installsuffix netgo -ldflags="$(LDFLAGS) -extldflags '-static'" -o bin/$(NAME)

docker-build: Dockerfile Gopkg.lock
	docker build -t $(PROJECT)/$(NAME):$(VERSION) .

docker-push:
	docker push $(PROJECT)/$(NAME):$(VERSION)

test:
	go test -v

clean:
	rm -rf bin vendor

tag:
	git tag $(VERSION)

vendor: Gopkg.toml
	dep ensure

Gopkg.lock:
	dep ensure

Gopkg.toml:
	dep init

Dockerfile: Dockerfile.tmpl
	NAME=$(NAME) sh $< > $@

.PHONEY: build static-build docker-build docker-push test clean tag
