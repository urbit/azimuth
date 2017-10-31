
# Ships: interface

The Ships contract contains all the important state about Urbit ships.  
All of its functions are getters, setters and checks. Other than the fact that the setters can only be called by the Ships contract owner (the Constitution), these are all fairly straightforward. The stored data, on the other hand, is interesting and important enough to be elaborated upon.

## Structs & enums

### `struct Hull`

The `Hull` represents a ship's full state. It contains the following pieces of data:

**`address pilot`**  
The current owner of the ship.

**`Status status`**
See `struct Status` below.

**`uint16 children`**  
The amount of children the ship has launched. This, in combination with the `status`, is used by the Constitution to determine whether a galaxy is allowed to launch more stars.

**`bytes32 key`**  
The current public key of the ship on the Urbit network, `0` if it has none.

**`uint256 revision`**  
The revision number of the public key.

**`uint16 parent`**  
The current parent under which the ship resides on the Urbit network.

**`uint32 escape`**  
The parent to which the ship has requested to fall under. `65536` if no such request is active. (`0` is a valid parent, so can't be used to indicate this.)

**`mapping(address => bool) launchers`**  
Addresses that have permission to launch child ships using this ship. Useful for automating distribution of ships.

**`address transferrer`**  
An address that is allowed to transfer ownership of the ship, just like its pilot can.

### `enum State`

A ship progresses through three operating states:

- **`Latent`**: The ship is still owned by its parent ship.
- **`Locked`**: The ship now belongs to an Ethereum address, but cannot be used on the live network or transferred to a new owner until the "lock time" passes.
- **`Living`**: The ship is active on the live network.

### `struct Status`

The `Status` contains the current `State` of the ship and details on how far along that state it is.

**`State state`**  
See `enum State` above.

**`uint64 locked`**  
Timestamp until which the ship can't progress past the `Locked` state.

**`uint64 completed`**  
Timestamp at which a galaxy has access to all of its stars. The Constitution enforces that a galaxy can only launch up to a percentage of its stars equivalent to the current timestamp on a scale from `locked` to `completed`.

## Contract state

**`mapping(uint32 => Hull) internal ships`**  
The `ships` mapping is where the vast bulk of data is stored. It contains state for all the Urbit ships, as described above.

**`mapping(address => uint32[]) public pilots`**  
Per Ethereum address, a list of its owned ships is tracked, so their "fleet" is easily browsable.

**`mapping(address => mapping(uint32 => uint256))`**  
Per Ethereum address, we keep track of each ship's position (index + 1) in the address' `pilots` array, so that we can efficiently delete entries from it when ownership changes.
