


dev-test :; forge test --verbosity -vvv --watch

anvil :; anvil -m 'test test test test test test test test test test test junk'

deploy-anvil :; forge script script/${contract}.s.sol:Deploy${contract} \
	--rpc-url http://localhost:8545  \
	--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	--broadcast

deploy-sepolia :; forge script script/${contract}.s.sol:Deploy${contract} \
	--rpc-url ${RPC_URL}  \
	--private-key ${PRIVATE_KEY} \
	--broadcast

coverage :; forge coverage --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage

show-coverage :; npx http-server ./coverage