
# Votes: interface

The Votes contract powers the voting mechanism used by the Constitution to determine when to upgrade, and to which address. It allows galaxies (galaxy owners) to vote on two distinct kinds of proposals:  
*Concrete* proposals are addresses of Constitution contracts to upgrade to.  
*Abstract* proposals are hashes of documents.

## Data

**`uint8 public totalVoters`**  
The Votes contract depends on the Constitution to tell it how many active voters there are. Since this amount can only ever increase, this is done by calling `incrementTotalVoters()`.  
When determining whether a proposal has achieved majority, `totalVoters` is used to calculate how many votes are required.

**`mapping(address => mapping(address => bool[256])) private concreteVotes`**  
In order to prevent weird scenarios wherein majorities quickly follow each other, potentially resulting in unintentional or broken upgrades, we store concrete votes *per Constitution address*. That is to say, whenever the Constitution upgrades, all votes get reset.

**`mapping(address => mapping(address => uint8)) public concreteVoteCounts`**  
To be able to check for majorities without having to recount all 256 votes, we keep track of vote counts per proposal incrementally. (And again, we do this *per Constitution address*.)

**`mapping(bytes32 => bool[256]) private abstractVotes`**  
Just like for concrete proposals, we keep track of individual abstract votes. Note that abstract proposals are hashes (`bytes32`), not addresses.

**`mapping(bytes32 => uint8) public abstractVoteCounts`**  
And here, too, we track vote counts to avoid having to recount when checking for majority.

**`mapping(bytes32 => bool) public abstractMajorityMap`**  
For abstract proposals, we also keep track of whether a proposal has ever achieved majority, so that it can be frozen once that has happened.

**`bytes32[] public abstractMajorities`**  
Like `abstractMajorityMap`, but easier to read for off-chain use.

## Functions

### Cast concrete vote

**Interface:**  
`castConcreteVote(uint8 _galaxy, address _proposal, bool _vote)`

**Description:**  
Cast a vote on a concrete proposal: whether to support an upgrade of the Constitution to the specified address or not.

**Requirements:**  
- The proposal must not be the current Constitution.
- The vote must be different from what is currently registered.

**Result:**  
- Registers the vote.
- Increments or decrements the vote-count for the proposal, according to the vote.
- Returns `true` if a majority has been achieved, `false` otherwise.

### Cast abstract vote

**interface:**  
`castAbstractVote(uint8 _galaxy, bytes32 _proposal, bool _vote)`

**Description:**  
Cast a vote on an abstract proposal: whether or not to support the contents of the document whose hash is that of the proposal.

**Requirements:**  
- The proposal must not have achieved majority before.
- The vote must be different from what is currently registered.

**Result:**  
- Registers the vote.
- Increments or decrements the vote-count for the proposal, according to the vote.
- If a majority has been achieved, it records that in contract state.
