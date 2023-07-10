#!/bin/bash

export REMOTE=sepolia

forge script script/DeployMirrorTokens.s.sol --legacy --verify --broadcast --aws true -vv
