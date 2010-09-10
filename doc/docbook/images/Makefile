DEST=activation.png description.png intro.png maintain.png nbboot.png source.png types.png

all:${DEST}

activation.png:activation.fig
	convert activation.fig -rotate 90 -trim ../../images/activation.png
	ln -s ../../images/activation.png activation.png

description.png:description.fig
	convert description.fig -rotate 90 -trim ../../images/description.png
	ln -s ../../images/description.png description.png

intro.png:intro.fig
	convert intro.fig -rotate 90 -trim ../../images/intro.png
	ln -s ../../images/intro.png intro.png

maintain.png:maintain.fig
	convert maintain.fig -trim ../../images/maintain.png
	ln -s ../../images/maintain.png maintain.png

nbboot.png:nbboot.fig
	convert nbboot.fig -trim ../../images/nbboot.png
	ln -s ../../images/nbboot.png nbboot.png

source.png:source.fig
	convert source.fig -rotate 90 -trim ../../images/source.png
	ln -s ../../images/source.png source.png

types.png:types.fig
	convert types.fig -rotate 90 -trim ../../images/types.png
	ln -s ../../images/types.png types.png

clean:
	rm -f *.png
