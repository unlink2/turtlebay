all:
	dasm main.asm -f3 -v5 -o./bin/game.bin -l./bin/game.lst -s./bin/game.sym

clean:
	rm ./bin/*.bin
