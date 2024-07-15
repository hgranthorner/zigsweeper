# zigsweeper

It's minesweeper, but in Zig and Raylib.

![Image of current state of the game](https://github.com/hgranthorner/zigsweeper/blob/main/images/example.png?raw=true)

## Building and running

Ensure you have zig 0.13 installed (`zig build` tends to break between minor versions, so make sure to have that specific version installed).

`zig build run`

## TODO

- [X] Set up winning and losing states
- [ ] Convert everything to rec collisions
- [ ] Be able to reset the game
- [ ] Choose your difficulty
- [ ] Properly center mine numbers
- [ ] Improve testing
- [ ] Set up e2e testing?
