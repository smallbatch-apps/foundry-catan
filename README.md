# Blockchain Catan

The rules for Catan written in Solidity for EVM platforms. Application is under active development, with the intent to add a feature or rule per day.

Application is written in Solidity version 0.8.18 and scaffolded with Foundry. To run checkout this repository and run it in Foundry. To test run `forge test`.

## Features and rules

- ~~Players~~
  - ~~Ability to join~~
  - ~~Colours~~
- ~~Dice roll~~
- ~~Board initial structure and graph~~
- ~~Board resource generation assignment and randomisation~~
  - ~~Generate terrain/resources~~
  - ~~assign numbers for hexes~~
- ~~Road placement~~
  - ~~Must join to an existing player road~~
  - ~~Must transfer resources to bank~~
  - ~~Must be connected to a settlement or road~~
  - ~~Cannot be placed on an edge blocked by opponent~~
- ~~Settlement placement~~
  - ~~Cannot place within a space of another settlement~~
  - ~~Must place on your road~~
  - ~~Must have the resources~~
  - ~~Cannot have more than 5 settlements~~
- ~~City upgrading~~
  - ~~Must already be settlement~~
  - ~~cannot have more than 4 cities~~
  - ~~Upgrade node~~
  - ~~Implement cost~~
- ~~Resource assignment on rolling~~
  - ~~Assign resources to players based on dice roll~~
  - ~~Robber prevents settlement gaining resources~~
- ~~Initial settlement placement~~
  - ~~Randomise order of players~~
  - ~~First to last then last to first~~
  - ~~Lay road~~
  - ~~Second placement gets resources~~
- ~~Trading~~
  - ~~Bank trading~~
  - ~~Bank Trading with ports~~
  - ~~Human trading~~
- ~~Rolling the robber~~
  - ~~Robber triggered on a 7~~
  - ~~Move the robber to a chosen hex~~
  - ~~Steal a resource from a chosen player~~
  - ~~Player with excess resources robbed~~
- ~~Resource cards~~
  - ~~Create deck of cards~~
  - ~~Shuffle deck~~
  - ~~Draw card~~
  - ~~Knight~~
  - ~~Monopoly~~
  - ~~Year of plenty~~
  - ~~Road building~~
- ~~Longest road~~
  - ~~check for new settlement breaking longest road~~
- ~~Largest army~~
- ~~Winning~~
