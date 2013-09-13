DEST=activation.png description.png intro.png maintain.png nbboot.png source.png types.png

all:${DEST}

activation.png:activation.fig
	convert activation.fig -alpha copy -channel alpha -rotate 90 -trim ../../images/activation.png

description.png:description.fig
	convert description.fig -alpha copy -channel alpha -rotate 90 -trim ../../images/description.png

intro.png:intro.fig
	convert intro.fig -alpha copy -channel alpha -rotate 90 -trim ../../images/intro.png

maintain.png:maintain.fig
	convert maintain.fig -alpha copy -channel alpha -trim ../../images/maintain.png

nbboot.png:nbboot.fig
	convert nbboot.fig -alpha copy -channel alpha -trim ../../images/nbboot.png

source.png:source.fig
	convert source.fig -alpha copy -channel alpha -rotate 90 -trim ../../images/source.png

types.png:types.fig
	convert types.fig -alpha copy -channel alpha -rotate 90 -trim ../../images/types.png

cache.png:cache.fig
	convert cache.fig -alpha copy -channel alpha -rotate 90 -trim ../../images/cache.png
