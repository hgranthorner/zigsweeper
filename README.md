# zigsweeper

It's minesweeper, but in Zig and Raylib.

![Image of current state of the game](https://github.com/hgranthorner/zigsweeper/blob/main/images/example.png?raw=true)

## Building and running

Ensure you have zig 0.13 installed (`zig build` tends to break between minor versions, so make sure to have that specific version installed).

`zig build run`

## TODO

- [X] Set up winning and losing states
- [X] Be able to reset the game
- [X] Choose your difficulty
- [X] Properly center mine numbers
- [ ] Show flag counter and number of mines remaining
- [ ] Implement right clicking on uncovered square to uncover all surrounding squares if all surrounding mines have been flagged
- [ ] Improve testing
- [ ] Set up e2e testing?
- [ ] Improve graphics
