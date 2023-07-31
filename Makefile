
install:
    brew install ekhtml
    brew install lcov

coverage:
    forge coverage --report lcov
    genhtml lcov.info --branch-coverage --output-dir coverage
	echo "Coverage report generated at coverage/index.html"

dev-test :; forge test --verbosity -vvv --watch --match-contract ${contract} --match-test ${test}