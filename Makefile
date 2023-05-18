SOURCES := $(wildcard *.pas)

checkers: $(SOURCES)
	fpc -Mobjfpc -Sh checkers -ghl -dDEBUG

clean:
	rm -f *.bak
	rm -f *.log
	rm -f *.o
	rm -f *.ppu
