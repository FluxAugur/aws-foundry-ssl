SHELL = /bin/bash
.SHELLFLAGS = -euco pipefail

AWSCLI      		:= aws

FOUNDRY_DOWNLOAD_LINK 	?= https://drive.google.com/file/d/1zCZJMV3WJ5YiIiQE4h0GLiYimpBuEkn-/view?usp=sharing
EMAIL 			?= nate@roleplaying.world
KEYPAIR_NAME 		?= foundry-games-roleplaying-world
DOMAIN 			?= games.roleplaying.world
TOP_DOMAIN_API_KEY	?= REQUIRED
TOP_DOMAIN_API_SECRET	?= REQUIRED
SUB_DOMAIN_API_KEY	?= REQUIRED
SUB_DOMAIN_API_SECRET 	?= REQUIRED
STACK_NAME		?= foundry-games-roleplaying-world
S3_BUCKET		?= foundry-files-roleplaying-world

validate:
	@echo "validate all the things..."
	@cfn-lint cloudformation/foundry_server.yaml
	@cfn-lint cloudformation/management_api.yaml

clean: ##=> Clean all the things
	$(info [+] Cleaning dist packages...)
	@if [ -f management_api.out.yaml ]; then rm management_api.out.yaml; fi
	@if [ -f handler.zip ]; then rm -rf handler.zip; fi

build: clean
	$(info [+] Build service zip)
	@cd src && zip -X -q -r9 $(abspath ./handler.zip) ./ -x \*__pycache__\* -x \*.git\*

sam-local: build
	sam local invoke \
		--template-file cloudformation/management_api.yaml \
		--event test/test.json

package:
	$(info [+] Transform forwarders SAM template and upload to S3)
	@aws cloudformation package \
		--template-file cloudformation/management_api.yaml \
		--output-template-file management_api.out.yaml \
		--s3-bucket staging-files-roleplaying-world

deploy-api:
	$(AWSCLI) cloudformation deploy --no-fail-on-empty-changeset \
		--stack-name api-$(STACK_NAME) \
		--template-file management_api.out.yaml \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameter-overrides \
			S3BucketName=$(S3_BUCKET) \
			CertArn=$(shell aws acm list-certificates --query "CertificateSummaryList[?DomainName=='api.foundry.$(DOMAIN)'].CertificateArn" --output text) \
		--tags \
			owner=nate \
			subdomain=games \
			app=foundry \
			interface=api

deploy:
	$(AWSCLI) cloudformation deploy --no-fail-on-empty-changeset \
		--stack-name $(STACK_NAME) \
		--template-file cloudformation/foundry_server.yaml \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameter-overrides \
			TakeSnapshots=False \
			FoundryDownloadLink="$(FOUNDRY_DOWNLOAD_LINK)" \
			UseExistingBucket=True \
			S3BucketName=$(S3_BUCKET) \
			SnapshotFrequency=Weekly \
			OptionalFixedIP=True \
			InstanceKey=$(KEYPAIR_NAME) \
			InstanceType=t2.medium \
			AMI="/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2" \
			FullyQualifiedDomainName=$(DOMAIN) \
			SubdomainName=foundry \
			APIKey=$(SUB_DOMAIN_API_KEY) \
			APISecret=$(SUB_DOMAIN_API_SECRET) \
			Email=$(EMAIL) \
			DomainRegistrar=amazon \
			WebServerBool=True \
			GoogleAPIKey=$(TOP_DOMAIN_API_KEY) \
			GoogleAPISecret=$(TOP_DOMAIN_API_SECRET) \
		--tags \
			owner=nate \
			subdomain=games \
			app=foundry
