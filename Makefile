# Commands:
#  make                        -- to compile elpi
#  make install                -- to install elpi using findlib
#  make install-bin BIN=path   -- to install the elpi REPL in $BIN
#  make uninstall              -- to remove elpi using findlib
#  make uninstall-bin BIN=path -- to remove the elpi REPL in $BIN
#  ... BYTE=yes                -- to compile/install/remove byte code
#
#  make git/V -- to compile elpi.git.V out of git's commit/branch/tag V
#                such binary is then picked up automatically by the bench
#                system as an elpi like runner
#  make runners -- foreach git tag runner-V, do something like make git/V 

BASE=$(shell pwd)
include Makefile.common

all: check-ocaml-ver elpi$(EXE)

byte:
	$(H)$(MAKE) BYTE=1 all

trace_ppx: trace_ppx.ml
	$(H)$(call pp,OCAMLOPT,-o,$@)
	$(H)ocamlfind ocamlopt -package ppx_tools_versioned.metaquot_402 \
		-package ocaml-migrate-parsetree.driver-main \
		-open Ast_402 \
		-c $< 
	$(H)ocamlfind ocamlopt -package ppx_tools_versioned.metaquot_402 \
		-package ocaml-migrate-parsetree \
		-predicates custom_ppx,ppx_driver \
		-linkpkg -linkall \
		trace_ppx.cmx \
		`ocamlfind query -predicates native \
	       		ocaml-migrate-parsetree.driver-main -a-format` \
		-o $@
	$(H)cp .merlin.in .merlin
	$(H)echo "FLG -ppx '$(shell pwd)/trace_ppx --as-ppx'" >> .merlin

git/%:
	$(H)rm -rf "$$PWD/elpi-$*"
	$(H)mkdir "elpi-$*"
	$(H)git clone -l .. "elpi-$*"
	$(H)cd "elpi-$*" && git checkout "$*" && cd elpi && make
	$(H)cp "elpi-$*/elpi/elpi" "elpi.git.$*"
	$(H)rm -rf "$$PWD/elpi-$*"

runners:
	$(H)true $(foreach t,$(shell git branch --list 'runner*' | cut -c 3-),\
		&& $(MAKE) git/$(t) && \
		mv elpi.git.$(t) elpi.git.$(t:runner-%=%))

clean:
	$(H)rm -f src/*.cmo src/*.cma src/*.cmx src/*.cmxa src/*.cmi
	$(H)rm -f src/*.o src/*.a src/*.cmt src/*.cmti
	$(H)rm -f trace_ppx.cmx elpi_config.ml
	$(H)rm -f elpi.git.* trace_ppx elpi elpi.byte
	$(H)rm -f src/.depends src/.depends.parser 
	$(H)rm -f src/.depends.byte src/.depends.parser.byte
	$(H)rm -rf findlib/

dist:
	$(H)git archive --format=tar --prefix=elpi-$(V)/ HEAD . \
		| gzip > ../elpi-$(V).tgz

# compilation of elpi

OC_OPTIONS = -linkpkg $(OCAMLOPTIONS) $(FLAGS)

ELPI_LIBS = \
  elpi_quoted_syntax.elpi  elpi-checker.elpi  \
  pervasives.elpi lp-syntax.elpi \
  utils/elpi2html.elpi

ELPI_DIST = \
  $(addprefix src/,elpi_API.cmi elpi_API.mli elpi.cmi)

ELPI_DIST_OPT = \
  $(addprefix src/,elpi.cma elpi.cmxa elpi.a elpi_API.cmti)

elpi$(EXE): elpi_REPL.ml elpi_config.$(CMX) findlib/elpi/META
	$(H)$(call pp,$(OCNAME),-package elpi elpi_config.$(CMX) -o $@,$<)
	$(H)$(OC) $(OC_OPTIONS) -package elpi elpi_config.$(CMX) -o $@ $<

elpi_config.$(CMX): elpi_config.ml
	$(H)$(call pp,$(OCNAME),-c, $<)
	$(H)$(OC) $(OC_OPTIONS) -c $<

elpi_config.ml:
	$(H)echo 'let install_dir = "$(shell ocamlfind printconf destdir)/elpi"' > $@

src/%: | trace_ppx
	$(H)$(MAKE) --no-print-directory -C src/ $*

src/elpi.$(CMXA): $(wildcard src/*.ml) $(wildcard src/*.mli)
findlib/elpi/META: src/elpi.$(CMXA) src/elpi.cmi Makefile
	$(H)rm -rf findlib/; mkdir findlib
	$(H)ocamlfind install -destdir $(BASE)/findlib -patch-archives \
		elpi META $(ELPI_DIST) $(ELPI_LIBS) \
		-optional $(ELPI_DIST_OPT)

install:
	$(H)ocamlfind install -patch-archives \
		elpi META $(ELPI_DIST) $(ELPI_LIBS) \
		-optional $(ELPI_DIST_OPT) elpi elpi.byte
install-bin:
	$(H)cp elpi$(EXE) $(BIN)

uninstall:
	$(H)ocamlfind remove elpi
uninstall-bin:
	$(H)rm -f $(BIN)/elpi$(EXE)


# required OCaml package
check-ocaml-ver:
	$(H)ocamlfind query camlp5 > /dev/null
	$(H)ocamlfind query ppx_tools_versioned > /dev/null
	$(H)ocamlfind query ppx_deriving > /dev/null
	$(H)ocamlfind query ocaml-migrate-parsetree.driver-main > /dev/null
