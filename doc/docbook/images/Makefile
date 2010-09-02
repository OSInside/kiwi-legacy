DEST=activation.png description.png intro.png maintain.png nbboot.png source.png types.png

all:${DEST}

activation.png:activation.fig
	convert activation.fig -rotate 90 -trim activation.png

description.png:description.fig
	convert description.fig -rotate 90 -trim description.png

intro.png:intro.fig
	convert intro.fig -rotate 90 -trim intro.png

maintain.png:maintain.fig
	convert maintain.fig -trim maintain.png

nbboot.png:nbboot.fig
	convert nbboot.fig -trim nbboot.png

source.png:source.fig
	convert source.fig -rotate 90 -trim source.png

types.png:types.fig
	convert types.fig -rotate 90 -trim types.png

clean:
	rm -f *.png
