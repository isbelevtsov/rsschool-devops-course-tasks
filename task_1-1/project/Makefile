.PHONY: init apply plan scan destroy clean fmt lint pre-commit cert
-include .env

CURRENT_DIR=${shell pwd}
DATE=$$(date +%F_%H-%M-%S)
TF := $(shell command -v terraform 2> /dev/null)

tools:
	@brew tap hashicorp/tap
	@brew install hashicorp/tap/terraform
	@brew install tflint pre-commit
	@pre-commit install

config-template:
	@cp .env.example .env
	@cp terraform.auto.tfvars.example terraform.auto.tfvars

initialize: tools config-template

init:
ifndef TF
    $(error "TF is not installed. Please install terraform tool from you package manager")
endif
	@terraform init

migrate:
ifndef TF
    $(error "TF is not installed. Please install terraform tool from you package manager")
endif
	@terraform init -migrate-state

plan:
ifndef TF
    $(error "TF is not installed. Please install terraform tool from you package manager")
endif
	@terraform plan

apply:
ifndef TF
    $(error "TF is not installed. Please install terraform tool from you package manager")
endif
	@terraform apply -auto-approve

destroy:
ifndef TF
    $(error "TF is not installed. Please install terraform tool from you package manager")
endif
	@terraform destroy -auto-approve

clean:
	@rm -rf .terraform terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl

pre-commit:
	@pre-commit run -a

lint:
	@tflint

fmt:
	@terraform fmt -recursive
