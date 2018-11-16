# Azimuth

A general-purpose PKI on the Ethereum blockchain.

This is a work in progress nearing completion. Feel free to poke around and open issues or ask questions. The [Urbit fora](https://urbit.org/fora) is also a good place for open-ended discussion related to this repo.

## Overview

This is just a quick summary of the different contracts and their purposes. For more detailed descriptions, check out the contracts themselves.

* **Ships**: contains all on-chain state for ships. Most notably, ownership and public keys. Can't be modified directly, you must use the Constitution.
* **Constitution**: is used as an interface for interacting with your ships on-chain. Allows you to configure keys, transfer ownership, etc.
* **Polls**: registers votes by the senate on proposals. These can be either static documents or Constitution upgrades.
* **Delegated Sending**: allows stars to let their planets send brand new planets to their friends and family.
* **Linear Star Release**: facilitates the release of blocks of stars to their owners over a period of time.
* **Conditional Star Release**: facilitates the release of blocks of stars to their owners based on milestones.
* **Planet Sale**: gives an example of a way in which stars could sell planets on-chain.

## Running

Install dependencies. Most notable inclusion is [Zeppelin-Solidity](https://openzeppelin.org/).

```
npm install
```

Build, deploy and test via [Truffle](http://truffleframework.com/) using the following commands:

```
npx truffle compile
npx truffle deploy
npx truffle test
```

When verifying deployed contracts on services like Etherscan, be sure to use [truffle-flattener](https://github.com/alcuadrado/truffle-flattener) for flattening contracts into single files.

## Tests

To run the test suite automatically, use a simple:

```
npm test
```

This will spin up a local [Ganache](https://github.com/trufflesuite/ganache-cli) node in the background.  If you'd like to use a persistent node, you can run

```
npx ganache-cli --gasLimit 6000000
```

and then test via `npx truffle test`.

The Planet Sale's test relating to withdrawing ETH from the contract are known to be finicky during tests, and may not always complete successfully.
