#!/bin/bash

# Generate keypair
aws ec2 create-key-pair --key-name foundry-games-roleplaying-world --query 'KeyMaterial' --output text > ./foundry-games-roleplaying-world.pem
