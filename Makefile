PROGRAM=tinygdb

.SILENT:

$(PROGRAM): $(PROGRAM).asm production.asm
	nasm -f bin -o $(PROGRAM) -l $(PROGRAM).list $(PROGRAM).asm -p production.asm
	chmod +x $(PROGRAM)

debug: $(PROGRAM).asm debug.asm
	nasm -f elf64 -F dwarf -g -o $(PROGRAM).o -l $(PROGRAM).list $(PROGRAM).asm -p debug.asm
	ld -N -e e_padding -o $(PROGRAM) $(PROGRAM).o

run: $(PROGRAM)
	./$(PROGRAM)

.PHONY: clean

clean:
	rm $(PROGRAM) $(PROGRAM).o $(PROGRAM).list
