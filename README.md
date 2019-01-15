# Azimuth

A general-purpose PKI, live on the Ethereum blockchain.

## Overview

This is just a quick summary of the different contracts and their purposes. For more detailed descriptions, see the inline documentation in the contracts themselves.

* **Azimuth**: contains all on-chain state for azimuth. Most notably, ownership and public keys. Can't be modified directly, you must use the Ecliptic.
* **Ecliptic**: is used as an interface for interacting with your points on-chain. Allows you to configure keys, transfer ownership, etc.
* **Polls**: registers votes by the Galactic Senate on proposals. These can be either static documents or Ecliptic upgrades.
* **Linear Star Release**: facilitates the release of blocks of stars to their owners over a period of time.
* **Conditional Star Release**: facilitates the release of blocks of stars to their owners based on milestones.
* **Claims**: allows point owners to make claims about (for example) their identity, and associate that with their point.
* **Censures**: simple reputation management, allowing galaxies and stars to flag points for negative reputation.
* **Delegated Sending**: enables network-effect like distributing of planets.
* **Planet Sale**: gives an example of a way in which stars could sell planets on-chain.

## Live contracts

The core Azimuth contracts can be found on the Ethereum blockchain.

* **Azimuth**: [azimuth.eth / `0x223c067f8cf28ae173ee5cafea60ca44c335fecb`](https://etherscan.io/address/azimuth.eth)
* **Ecliptic**: [ecliptic.eth / `0x6ac07b7c4601b5ce11de8dfe6335b871c7c4dd4d`](https://etherscan.io/address/ecliptic.eth)
* **Polls**: [`0x7fecab617c868bb5996d99d95200d2fa708218e4`](https://etherscan.io/address/0x7fecab617c868bb5996d99d95200d2fa708218e4)
* **Linear Star Release**: [`0x86cd9cd0992f04231751e3761de45cecea5d1801`](https://etherscan.io/address/0x86cd9cd0992f04231751e3761de45cecea5d1801)
* **Conditional Star Release**: [`0x8c241098c3d3498fe1261421633fd57986d74aea`](https://etherscan.io/address/0x8c241098c3d3498fe1261421633fd57986d74aea)
* **Claims**: [`0xe7e7f69b34d7d9bd8d61fb22c33b22708947971a`](https://etherscan.io/address/0xe7e7f69b34d7d9bd8d61fb22c33b22708947971a)
* **Censures**: [`0x325f68d32bdee6ed86e7235ff2480e2a433d6189`](https://etherscan.io/address/0x325f68d32bdee6ed86e7235ff2480e2a433d6189)
* **Delegated Sending**: [`0xf6b461fe1ad4bd2ce25b23fe0aff2ac19b3dfa76`](https://etherscan.io/address/0xf6b461fe1ad4bd2ce25b23fe0aff2ac19b3dfa76)
* **Planet Sale**: Deploy It Yourself!

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

(The Planet Sale's test relating to withdrawing ETH from the contract are known to be finicky during tests, and may not always complete successfully.)
