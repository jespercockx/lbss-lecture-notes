
default: langsec.pdf

%.pdf: _build/%.pdf Makefile
	cp $< $@

_build/%.pdf: _build/%.tex Makefile
	latexmk -pdf -pdflatex="xelatex -halt-on-error -interaction=nonstopmode %O %S" -auxdir=_build -outdir=_build -use-make $<

_build/%.tex: _build/%.md Makefile
	pandoc --no-highlight --number-sections -s $< -o $@

_build/langsec.md: common.md 01_introduction.md 02_tracing_semantics.md 03_dynamic_analysis.md 04_taint_analysis.md 05_static_type_checking.md 06_security_types.md 07_substructural_type_systems.md 08_abstract_interpretation.md Makefile
	mkdir -p _build
	cat common.md 01_introduction.md 02_tracing_semantics.md 03_dynamic_analysis.md 04_taint_analysis.md 05_static_type_checking.md 06_security_types.md 07_substructural_type_systems.md 08_abstract_interpretation.md > $@

_build/%.md: %.md Makefile
	mkdir -p _build
	cat common.md $< > $@

.PHONY: clean
clean: Makefile
	rm -r _build || true

.PHONY: realclean
realclean: clean Makefile
	rm *~ || true
	rm *.pdf || true
