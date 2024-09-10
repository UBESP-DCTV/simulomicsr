# https://stackoverflow.com/a/18137056 
mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
name := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))

image := dlwr
version ?= latest

psw ?= psw

all: restart

restart: stop remove run

stop:
	docker stop $(name) || exit 0

remove:
	docker rm $(name) || exit 0

run:
	docker run -d --rm --name $(name) -e PASSWORD=$(psw) -v ${CURDIR}:/home/rstudio/$(name) --gpus all -p 8787:8787 corradolanera/$(image):$(version)
