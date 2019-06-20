export IMAGE_NAME?=insightful/ubuntu-gerbil
export VCS_REF=`git rev-parse --short HEAD`
export VCS_URL=https://github.com/insightfulsystems/ubuntu-gambit
export BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"`
export TAG_DATE=`date -u +"%Y%m%d"`
export BASE_IMAGE=insightful/ubuntu-gambit
export TARGET_ARCHITECTURES=amd64 arm64v8 arm32v7
export SHELL=/bin/bash

# Permanent local overrides
-include .env

.PHONY: build qemu wrap push manifest clean

qemu:
	-docker run --rm --privileged multiarch/qemu-user-static:register --reset

build:
	$(foreach ARCH, $(TARGET_ARCHITECTURES), make build-$(ARCH);)

wrap-%: # bogus task for pipeline uniformity
	$(eval ARCH := $*)

build-%:
	$(eval ARCH := $*)
	docker build --build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg ARCH=$(ARCH) \
		--build-arg BASE=$(BASE_IMAGE):$(ARCH) \
		--build-arg VCS_REF=$(VCS_REF) \
		--build-arg VCS_URL=$(VCS_URL) \
		-t $(IMAGE_NAME):$(ARCH) src
	@echo "--- Done building $(ARCH) ---"

push:
	docker push $(IMAGE_NAME)

push-%:
	$(eval ARCH := $*)
	docker push $(IMAGE_NAME):$(ARCH)

expand-%: # expand architecture variants for manifest
	@if [ "$*" == "amd64" ] ; then \
	   echo '--arch $*'; \
	elif [[ "$*" == *"arm"* ]] ; then \
	   echo '--arch arm --variant $*' | cut -c 1-21,27-; \
	fi

setup-manifest:
	@if [ ! -f "~/.docker/config.json" ] ; then \
		mkdir ~/.docker && \
		echo '{ "experimental": "enabled" }' > ~/.docker/config.json ; \
	fi

build-manifest:
	docker --config ~/.docker manifest create --amend \
		$(IMAGE_NAME):latest \
		$(foreach arch, $(TARGET_ARCHITECTURES), $(IMAGE_NAME):$(NODE_MAJOR_VERSION)-$(arch) )
	$(foreach arch, $(TARGET_ARCHITECTURES), \
		docker manifest annotate \
			$(IMAGE_NAME):latest \
			$(IMAGE_NAME):$(NODE_MAJOR_VERSION)-$(arch) $(shell make expand-$(arch));)

push-manifest:
	docker --config ~/.docker manifest push $(IMAGE_NAME):latest

clean:
	-docker rm -fv $$(docker ps -a -q -f status=exited)
	-docker rmi -f $$(docker images -q -f dangling=true)
	-docker rmi -f $(BUILD_IMAGE_NAME)
	-docker rmi -f $$(docker images --format '{{.Repository}}:{{.Tag}}' | grep $(IMAGE_NAME))
