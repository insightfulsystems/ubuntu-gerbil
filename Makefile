export IMAGE_NAME?=insightful/ubuntu-gerbil
export VCS_REF=`git rev-parse --short HEAD`
export VCS_URL=https://github.com/insightfulsystems/ubuntu-gambit
export BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"`
export TAG_DATE=`date -u +"%Y%m%d"`
export BASE_IMAGE=insightful/ubuntu-gambit
export TARGET_ARCHITECTURES=amd64 arm64v8 arm32v7
export DOCKER?=docker --config=~/.docker
export DOCKER_CLI_EXPERIMENTAL=enabled
export SHELL=/bin/bash

# Permanent local overrides
-include .env

.PHONY: build qemu wrap push manifest clean

qemu:
	@echo "==> Setting up QEMU"
	-$(DOCKER) run --rm --privileged multiarch/qemu-user-static:register --reset
	@echo "==> Done setting up QEMU"

wrap-%: # bogus task for pipeline uniformity
	$(eval ARCH := $*)

build:
	@echo "==> Building all containers"
	$(foreach ARCH, $(TARGET_ARCHITECTURES), make build-$(ARCH);)
	@echo "==> Done."

build-%:
	$(eval ARCH := $*)
	@echo "--> Building $(ARCH)"
	$(DOCKER) build --build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg ARCH=$(ARCH) \
		--build-arg BASE=$(BUILD_IMAGE_NAME):$(ARCH) \
		--build-arg VCS_REF=$(VCS_REF) \
		--build-arg VCS_URL=$(VCS_URL) \
		-t $(IMAGE_NAME):$(ARCH) src
	@echo "--> Done building $(ARCH)"

push:
	@echo "==> Pushing $(IMAGE_NAME)"
	$(DOCKER) push $(IMAGE_NAME)
	@echo "==> Done."

push-%:
	$(eval ARCH := $*)
	$(DOCKER) push $(IMAGE_NAME):$(ARCH)

expand-%: # expand architecture variants for manifest
	@if [ "$*" == "amd64" ] ; then \
	   echo '--arch $*'; \
	elif [[ "$*" == *"arm"* ]] ; then \
	   echo '--arch arm --variant $*' | cut -c 1-21,27-; \
	fi

manifest:
	@echo "==> Building multi-architecture manifest"
	$(foreach STEP, build push, make $(STEP)-manifest;)
	@echo "==> Done."	

build-manifest:
	@echo "--> Creating manifest"
	$(eval DOCKER_CONFIG := $(shell echo "$(DOCKER)" | cut -f 2 -d=)/config.json)
	cat $(DOCKER_CONFIG) | grep -v auth
	$(DOCKER) manifest create --amend \
		$(IMAGE_NAME):latest \
		$(foreach arch, $(TARGET_ARCHITECTURES), $(IMAGE_NAME):$(arch) )
	$(foreach arch, $(TARGET_ARCHITECTURES), \
		$(DOCKER) manifest annotate \
			$(IMAGE_NAME):latest \
			$(IMAGE_NAME):$(arch) $(shell make expand-$(arch));)

push-manifest:
	@echo "--> Pushing manifest"
	$(DOCKER) manifest push $(IMAGE_NAME):latest

clean:
	@echo "==> Cleaning up old images..."
	-$(DOCKER) rm -fv $$($(DOCKER) ps -a -q -f status=exited)
	-$(DOCKER) rmi -f $$($(DOCKER) images -q -f dangling=true)
	-$(DOCKER) rmi -f $(BUILD_IMAGE_NAME)
	-$(DOCKER) rmi -f $$($(DOCKER) images --format '{{.Repository}}:{{.Tag}}' | grep $(IMAGE_NAME))
	@echo "==> Done."