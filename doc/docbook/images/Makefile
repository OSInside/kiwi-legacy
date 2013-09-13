SOURCES=activation.fig description.fig intro.fig maintain.fig nbboot.fig source.fig types.fig
OBJECTS=$(SOURCES:.fig=.png)

all: $(SOURCES) $(OBJECTS)

activation.png:activation.fig
	fig2dev -L png -S4 activation.fig ../../images/activation.png

description.png:description.fig
	fig2dev -L png -S4 description.fig ../../images/description.png

intro.png:intro.fig
	fig2dev -L png -S4 intro.fig ../../images/intro.png

maintain.png:maintain.fig
	fig2dev -L png -S4 maintain.fig ../../images/maintain.png

nbboot.png:nbboot.fig
	fig2dev -L png -S4 nbboot.fig ../../images/nbboot.png

source.png:source.fig
	fig2dev -L png -S4 source.fig ../../images/source.png

types.png:types.fig
	fig2dev -L png -S4 types.fig ../../images/types.png

cache.png:cache.fig
	fig2dev -L png -S4 cache.fig ../../images/cache.png

clean:
	for i in ${DEST};do rm -f ../../images/$$i;done
