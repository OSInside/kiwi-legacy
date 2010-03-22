all: bootnext

bootnext: bootnext.asm
	nasm -O99 -f bin -l $@.lst -o $@ $<

clean:
	rm -f *~ bootnext *.lst

