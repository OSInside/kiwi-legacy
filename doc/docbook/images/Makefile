DEST=activation.png description.png intro.png maintain.png nbboot.png source.png types.png

all:${DEST}

activation.png:activation.fig
	fig2dev -L png activation.fig activation.png

description.png:description.fig
	fig2dev -L png description.fig description.png

intro.png:intro.fig
	fig2dev -L png intro.fig intro.png

maintain.png:maintain.fig
	fig2dev -L png maintain.fig maintain.png

nbboot.png:nbboot.fig
	fig2dev -L png nbboot.fig nbboot.png

source.png:source.fig
	fig2dev -L png source.fig source.png

types.png:types.fig
	fig2dev -L png types.fig types.png

clean:
	rm -f *.png
