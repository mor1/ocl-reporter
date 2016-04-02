INSTALL = brew install
PACKAGES = omd,cohttp.lwt,core,cow,cow.syntax,lwt,netstring,river,syndic,uri
OCAMLBUILD = ocamlbuild -j 4 -use-ocamlfind -syntax camlp4o -tag thread,annot

build:
	$(OCAMLBUILD) -package $(PACKAGES) lib/www.native

deps:
	opam pin -y add -n ocl-reporter .
	opam install --deps-only ocl-reporter
	opam pin -y remove ocl-reporter

clean:
	ocamlbuild -clean www.native
	$(RM) -r lint

run: build
	./www.native

www:
	cd pages \
	&& env PATH=../ucampas:$$PATH ucampas -i -r3 index people tasks papers news

check:
	[ -z $$(which linklint) ] && $INSTALL linklint || true
	$(RM) -r lint && mkdir -p lint
	linklint -net -doc lint -root pages /@

cron:
	git pull -u >/dev/null
	cd pages && rsync --delete -aqz . /anfs/www/html/projects/ocamllabs/
