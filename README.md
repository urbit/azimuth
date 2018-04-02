# The Urbit Constitution

The Urbit PKI on the Ethereum blockchain.  

This is a work in progress nearing completion. Feel free to poke around and open issues or ask questions. The [Urbit fora](https://urbit.org/fora) is also a good place for open-ended discussion related to this repo.

## Overview

This is just a quick summary of the different contracts and their purposes. For more detailed descriptions, check out the contracts themselves.

* **Ships**: contains all on-chain state for Urbit ships. Most notably, ownership and public keys. Can't be modified directly, you must use the Constitution.
* **Constitution**: is used as an interface for interacting with your ships on-chain. Allows you to configure keys, transfer ownership, etc.
* **Polls**: registers votes by the senate on proposals. These can be either static documents or Constitution upgrades.
* **Delegated Sending**: allows stars to let their planets send brand new planets to their friends and family.
* **Linear Star Release**: facilitates the release of blocks of stars to their owners over a period of time.
* **Conditional Star Release**: facilitates the release of blocks of stars to their owners based on milestones.
* **Planet Sale**: gives an example of a way in which stars could sell planets on-chain.
* **Pool**: gives an example of a way in which stars could be temporarily tokenized.

## Running

Install dependencies. Most notable inclusion is [Zeppelin-Solidity](https://openzeppelin.org/).

```
npm install
```

Build, deploy and test using [Truffle](http://truffleframework.com/).

```
npm install -g truffle
```

Use any of the following commands.

```
truffle compile
truffle deploy
truffle test
```

## Tests

To successfully run the tests, make sure [Ganache](https://github.com/trufflesuite/ganache-cli) (or any other RPC enabled node) is running locally.

```
ganache-cli --gasLimit 5000000
```

Some tests, most notably those for Polls and Star Releases, make heavy use of timing, and thus might be performance-dependent in some cases. Fixing this is nice, but not a priority. If they fail on you, try running them again. If they still fail, try tweaking the numbers in the test's setup.
