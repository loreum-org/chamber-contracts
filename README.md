## Loreum Chambers

Loreum Chambers are composable DAO governance smart contracts for the Ethereum Virtual Machine.

### Setup

Copy `.example.env` to `.env`

```
cp .example.env .env
```

`yarn` to install npm packages

```
yarn install
```

`yarn setup` to clone libs.

```
yarn setup
# Or
git submodule update --init --recursive
```

### Foundry

```
forge build
forge test --verbosity -vvv
```

### Hardhat

You'll need to open two terminals.

_Terminal 1_

```
yarn chain
```

_Terminal 2_

```
yarn compile
yarn deploy:local
```
