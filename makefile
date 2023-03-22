all:
	dasm main.asm -f3 -v5 -o./bin/tb.bin -l./bin/tb.lst -s./bin/tb.sym

clean:
	rm ./bin/*.bin
