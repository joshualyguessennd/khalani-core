#!/bin/bash

export REMOTE=fuji

forge script script/DeployMirrorTokens.s.sol --legacy --broadcast --private-key "${PRIVATE_KEY}" -vv
