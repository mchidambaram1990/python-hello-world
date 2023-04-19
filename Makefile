# use some sensible default shell settings
SHELL := /bin/bash
.SILENT:
.DEFAULT_GOAL := help

ENV:=dev
REACT_APP_DIR=react-app
REACT_BUILD_DIR=build
TFVARS_FILE=./deployment/${ENV}.tfvars
export TF_STATE_FILE = $(ENV).tfplan
export TF_ARTIFACT   = .terraform/$(TF_STATE_FILE)
TF ?= docker-compose run --rm terraform-utils
NODE ?= docker-compose run --rm nodejs

fmt:
	$(TF) terraform fmt --recursive
.PHONY: fmt

fmt_check:
	$(TF) terraform fmt -diff -check --recursive
.PHONY: fmt_check

validate: local-init
	$(TF) terraform validate
.PHONY: validate

local-init:
	$(TF) terraform init --backend=false
.PHONY: local-init

init:
	$(TF) terraform init
.PHONY: init

plan: init unzip_react_app
	$(TF) terraform plan --var-file ${TFVARS_FILE} -out ${TF_ARTIFACT}
ifdef CI
	$(TF) terraform show -json ${TF_ARTIFACT} | .buildkite/scripts/recordchange_and_annotate.sh $(ENV)
endif

.PHONY: plan

unzip_react_app:
	unzip -o ${REACT_APP_DIR}/${REACT_BUILD_DIR}.zip -d ${REACT_APP_DIR}
	cd ${REACT_APP_DIR} && ls -la
.PHONY: unzip_react_app

apply: init unzip_react_app
	$(TF) terraform apply --auto-approve ${TF_ARTIFACT}
.PHONY: apply

list:
	$(TF) terraform state list
.PHONY: list

show:
	$(TF) terraform show -json
.PHONY: show

unlock_state: init
	$(TF) terraform force-unlock -force ${LOCK_ID}
.PHONY: unlock_state

run_unit_tests_and_build:
	$(NODE) yarn install --production --frozen-lockfile
	$(NODE) yarn build
	cd ${REACT_APP_DIR} && zip -r ${REACT_BUILD_DIR}.zip ${REACT_BUILD_DIR}/*
.PHONY: run_unit_tests_and_build

default:
	@echo "Creates a Terraform system from a template."
	@echo "The following commands are available:"
	@echo " - validate           : runs terraform validate. This command will check and report errors within modules, attribute names, and value types."
	@echo " - fmt_check          : runs terraform format check"
	@echo " - plan               : runs terraform plan for an ENV"
	@echo " - apply              : runs terraform apply for an ENV"
