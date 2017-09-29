
# Constitution: interface

To better understand the data the constitution operates on, take a look at [the Ships contract](./contracts/Ships.sol).

## ++pub: transactions made by any Ethereum address

### Claim star

**Interface:**  
`claimStar(uint16 _star)`

**Description:**  
Spend a Spark to claim a star.

**Requirements:**  
- The chosen star must be `Liquid`.
- The caller must have a Spark balance of 1 or higher.
- The caller must have given the Constitution a Spark allowance of 1 or higher. (Also see the ERC20 standard.)

**Result:**  
- Assigns the caller as the star's owner.
- Sets the star to `Locked` with a release time equal to the timestamp of the current block.
- Withdraws 1 Spark from the caller and burns it.

## ++nav: transactions made by ship owners.

### Liquidate star

**Interface:**  
`liquidateStar(uint16 _star)`

**Description:**  
Liquidate a star to receive a Spark.

**Requirements:**  
- The caller must be the owner of the star's original parent.
- The parent of the star must be `Living`.
- The chosen star must be `Latent`.

**Result:**  
- Sets the star to `Liquid`.
- Mints 1 Spark and gives it to the caller.

### Launch

**Interface:**  
`launch(uint32 _ship, address _target)`

**Description:**  
Launch a star or planet, making a target address its owner.

**Requirements:**  
- The chosen ship must be `Latent`.
- The ship's original parent must be `Living`.
- The caller must either be the owner of the ship's parent, or have been given permission to launch ships in their stead.

**Result:**  
- Assigns the target address as the ship's owner.
- Sets the ship to `Locked` with a release time equal to the timestamp of the current block.

### Grant launch rights

**Interface:**  
`grantLaunchRights(uint16 _star, address _launcher)`

**Description:**  
Allow the given address to launch planets belonging to the star.  
(Could also be used for galaxies.)

**Requirements:**  
- The caller must be the owner of the star.
- The star must be `Living`.

**Result:**  
Registers permission for the address to launch planets for the star.

### Revoke launch rights

**Interface:**
`revokeLaunchRights(uint16 _star, address _launcher)`

**Description:**  
Disallow the given address to launch planets belonging to the star.

**Requirements:**
The caller must be the owner of the star.

**Result:**  
Revokes permission for the address to launch planets for the star.

### Start

**Interface:**  
`start(uint32 _ship, bytes32 _key)`

**Description:**  
Bring a locked ship to life and set its public key.

**Requirements:**  
- The caller must be the owner of the chosen ship.
- The ship must be `Locked`.
- The ship's release time must be in the past.

**Result:**  
- Sets the ship to `Living`.
- Sets the public key of the ship.
- If the ship is a galaxy, the amount of total voters (for the Votes contract) is incremented.

### Transfer ship

**Interface:**  
`transferShip(uint32 _ship, address _target)`

**Description:**  
Transfer a living ship to a different address.

**Requirements:**  
- The caller must be the owner of the chosen ship.
- The ship must be `Living`.
- The target address must not be the current owner.

**Result:**  
- Sets the public key of the ship to 0.
- Sets the owner of the ship to the target address.

### Rekey

**Interface:**  
`rekey(uint32 _ship, bytes32 _key)`

**Description:**  
Change the public key for a ship.

**Requirements:**  
- The caller must be the owner of the chosen ship.
- The ship must be `Living`.

**Result:**
Sets the public key of the ship to the given key.

### Escape

**Interface:**  
`escape(uint32 _ship, uint16 _parent)`

**Description:**  
Escape to a new parent. Takes effect when the new parent accepts the adoption.

**Requirements:**  
- The caller must be the owner of the chosen ship.
- The chosen new parent must be `Living`.

**Result:**  
Sets the escape of the ship to the chosen parent.

### Adopt

**Interface:**  
`adopt(uint16 _parent, uint32 _child)`

**Description:**  
Accept an escaping ship.

**Requirements:**  
- The caller must be the owner of the parent ship.
- The parent ship must be the child's chosen escape.

**Result:**  
- Sets the child's parent to be the parent ship.
- Unsets the child's escape.

### Reject

**Interface:**  
`reject(uint16 _parent, uint32 _child)`

**Description:**  
Reject an escaping ship.

**Requirements:**  
- The caller must be the owner of the parent ship.
- The parent ship must be the child's chosen escape.

**Result:**  
Unsets the child's escape.

## ++sen: Transactions made by galaxy owners

### Cast concrete vote

**Interface:**  
`castVote(uint8 _galaxy, address _proposal, bool _vote)`

**Description:**  
Vote on a new constitution contract.

**Requirements:**  
- The caller must be the owner of the galaxy.
- The galaxy must be `Living`.
- The proposed address must not be the current constitution's.
- The vote must be different from what is already registered.

**Result:**
- The vote for the proposal is registered.
- If the proposal attains a majority vote, ownership of all data contracts (Ships, Votes, Spark) is transferred to the proposed address, and the current Constitution is destroyed.

### Cast abstract vote

**Interface:**  
`castVote(uint8 _galaxy, bytes32 _proposal, bool _vote)`

**Description:**  
Vote on a documented proposal's hash.

**Requirements:**  
- The caller must be the owner of the galaxy.
- The galaxy must be `Living`.
- The vote must be different from what is already registered.

**Result:**  
- The vote for the proposal is registered.
- If the proposal attains a majority vote, it is appended to a list of abstract majorities.

## ++urg: transactions made by the Constitution owner

### Create galaxy

**Interface:**  
`createGalaxy(uint8 _galaxy, address _target, uint64 _date)`

**Description:**  
Assign initial galaxy owner and birthdate. Can only be done once.

**Requirements:**  
- The caller must be the owner of the Constitution contract.
- The chosen galaxy must not have an owner.

**Result:**
- Sets the galaxy's owner to the target address.
- Sets the galaxy to `Locked` with a release time at the specified date.
