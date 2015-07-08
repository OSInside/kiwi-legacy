FIGDIR := src/fig
PNGDIR := ../../images
SVGDIR := ./

figs := $(wildcard $(FIGDIR)/*.fig)
pngs := $(subst $(FIGDIR),$(PNGDIR),$(figs:.fig=.png))
svgs := $(subst $(FIGDIR),$(SVGDIR),$(figs:.fig=.svg))

all: $(pngs) $(svgs)

$(PNGDIR)/%.png: $(FIGDIR)/%.fig
	fig2dev -L png -S4 $< $@

$(SVGDIR)/%.svg: $(FIGDIR)/%.fig
	fig2dev -L svg $< $@

clean:
	rm -f $(pngs)
	rm -f $(svgs)
