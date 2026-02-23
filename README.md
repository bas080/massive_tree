# Massive Tree

> In Development (use creative to test)

The core idea of the mod is not just aesthetics but an attempt at creating simple rules that
result in a pleasant looking tree of massive size.

This mod delivers massive trees and ways to influence the growth of these tree and nothing more. The size of these trees are so big that they become biomes by themselves.

## Usage

`/giveme massive_tree:seed` or use creative inventory.

## Features

* Grow massive, trees with spreading leaves.
* Trees grow naturally over time, influenced by light and humidity.
* Leaves expand outward, creating full, lush canopies.
* Introducing Rotten Trees:
  * Dark, decayed appearance.
  * Can fall when players walk on them.
  * Appear naturally in areas without nearby leaves.
* Finished trees automatically settle into normal leaves for a polished look.
* Firefly support (if you have the fireflies mod installed):
  * Randomly spawn hidden fireflies around trees at night.

## Implementation

- The tree uses timers and grows real-time and not during map gen.
- Light is central to the decision making of these nodes. That is also the case for IRL trees.
- Once the tree is done growing the nodes are replaced with `default:leaves` nodes. You could remove the mod after the tree is generated.
