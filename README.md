# Azimuth

[![Build Status](https://secure.travis-ci.org/urbit/azimuth.png?branch=master)](http://travis-ci.org/urbit/azimuth)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/urbit/azimuth/blob/master/LICENSE)
[![npm](https://img.shields.io/npm/v/azimuth-solidity.svg)](https://www.npmjs.com/package/azimuth-solidity)

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
* **Ecliptic**: [ecliptic.eth / `0x9ef27de616154FF8B38893C59522b69c7Ba8A81c`](https://etherscan.io/address/ecliptic.eth)
* **Polls**: [`0x7fecab617c868bb5996d99d95200d2fa708218e4`](https://etherscan.io/address/0x7fecab617c868bb5996d99d95200d2fa708218e4)
* **Linear Star Release**: [`0x86cd9cd0992f04231751e3761de45cecea5d1801`](https://etherscan.io/address/0x86cd9cd0992f04231751e3761de45cecea5d1801)
* **Conditional Star Release**: [`0x8c241098c3d3498fe1261421633fd57986d74aea`](https://etherscan.io/address/0x8c241098c3d3498fe1261421633fd57986d74aea)
* **Claims**: [`0xe7e7f69b34d7d9bd8d61fb22c33b22708947971a`](https://etherscan.io/address/0xe7e7f69b34d7d9bd8d61fb22c33b22708947971a)
* **Censures**: [`0x325f68d32bdee6ed86e7235ff2480e2a433d6189`](https://etherscan.io/address/0x325f68d32bdee6ed86e7235ff2480e2a433d6189)
* **Delegated Sending**: [`0xf6b461fe1ad4bd2ce25b23fe0aff2ac19b3dfa76`](https://etherscan.io/address/0xf6b461fe1ad4bd2ce25b23fe0aff2ac19b3dfa76)
* **Planet Sale**: Deploy It Yourself!

## Galactic Senate

A suggested process for publicizing the proposals voted on by the Galactic Senate is described in [`senate.md`](./senate.md). Following that process, proposals that have been voted on and achieved majority can be found in [`proposals/`](./proposals/).

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

To run the contract test suite automatically, use a simple:

```
npm test
```

This will spin up a local [Ganache](https://github.com/trufflesuite/ganache-cli) node in the background.  If you'd like to use a persistent node, you can run

```
npx ganache-cli --gasLimit 6000000
```

and then test via `npx truffle test`.

For testing Ecliptic upgrades against whatever version of the contract is on mainnet, first run:

```
npm run fork-mainnet
```

This will start a local fork of mainnet, with the ownership addresses of the first 128 galaxies unlocked. Once that's ready, you can run the following in a seperate terminal:

```
npm run test-upgrade
//  or, to upgrade to a pre-existing contract, specify its address:
npm run test-upgrade -- --target='0xabcd...'
```

This will deploy the Ecliptic contract currently in the repository to the local fork (or refer to the specified upgrade target), and test if it can be upgraded to cleanly. Because this involves many transactions (for voting), this may take a couple minutes.

There are also tests located in `test-extras` that are not meant to be run via
a basic `npx truffle test` as they can fail nondeterministically.  You can run
these via:

```
npm run test-extras
```

