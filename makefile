all:
	dasm main.asm -f3 -v5 -o./bin/game.bin

clean:
	rm ./bin/*.bin
