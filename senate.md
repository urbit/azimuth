# Galactic Senate

The following is a suggestion to the Galactic Senate on how to expose its proposals to the public. The Senate is not required to adhere to this procedure, and the process described herein may be replaced by alternate suggestions.

At any point, before or after submission to the blockchain, before or after achieving majority, anyone may create a Pull Request containing a proposal.

For Ecliptic proposals, the PR should contain the new code for `contracts/Ecliptic.sol`, and any other changes needed to support it. If the contract has already been deployed to the Ethereum blockchain, the PR may mention its address.

For document proposals, the PR should contain the addition of a `.txt` file in `proposals/`, where its filename is the `keccak-256` hash of its contents.

When a proposal has achieved majority, as verified by looking up either the proposed Ecliptic contract address or the document's hash in `Polls.sol`'s `upgradeHasAchievedMajority(address)` or `documentHasAchievedMajority(bytes32)` respectively, the PR matching that proposal will be merged.