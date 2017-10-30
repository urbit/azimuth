
# Constitution: interface

To better understand the data the constitution operates on, take a look at [the Ships contract](./contracts/Ships.sol).

## ++nav: transactions made by ship owners.

### Launch

**Interface:**  
`launch(uint32 _ship, address _target, uint64 _lockTime)`

**Description:**  
Launch a star or planet, making a target address its owner. The launched ship becomes startable after the specified lock time.

**Requirements:**  
- The chosen ship must be `Latent`.
- The ship's original parent must be `Living`.
- The caller must either be the owner of the ship's parent, or have been given permission to launch ships in their stead.
- If the ship is a star, its parent must be allowed to birth another star.

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
`transferShip(uint32 _ship, address _target, bool _resetKey)`

**Description:**  
Transfer an unlocked or living ship to a different address, optionally resetting its key.

**Requirements:**  
- The caller must be the owner of the chosen ship.
- The ship must be either `Living`, or `Locked` with a locktime in the past.
- The target address must not be the current owner.

**Result:**  
- If `_resetKey` is true, sets the public key of the ship to 0.
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

## ++sen: transactions made by galaxy owners

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
- If the proposal attains a majority vote, ownership of all data contracts (Ships, Votes) is transferred to the proposed address, and the current Constitution is destroyed.

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
`createGalaxy(uint8 _galaxy, address _target, uint64 _lockTime, uint64 _completeTime)`

**Description:**  
Assign initial galaxy owner, lock date and completion date. Can only be done once.  
The lock date specifies the time at which the `Locked` galaxy may be made `Living`.  
The completion date is used to calculate how many stars the galaxy may have at any given time. This increases linearly from `1` to `256` between the lock time and completion time.

**Requirements:**  
- The caller must be the owner of the Constitution contract.
- The chosen galaxy must not have an owner.

**Result:**
- Sets the galaxy's owner to the target address.
- Sets the galaxy to `Locked` with a release time at the specified date.
- Sets the completion time of the galaxy to the specified date.
