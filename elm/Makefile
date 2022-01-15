MAKE_CASTLINK = elm make Castlink.elm --output $@
ELM_MAKE_ARGS = --optimize
ELM_JS = ../docs/elm.js
ELM_MIN_JS = ../docs/elm.min.js

all: $(ELM_MIN_JS)

.PHONY: $(ELM_JS)
$(ELM_JS):
	$(MAKE_CASTLINK) $(ELM_MAKE_ARGS)

$(ELM_MIN_JS): $(ELM_JS)
	uglifyjs $^ --compress 'pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe' | uglifyjs --mangle --output $@

format:
	elm-format --yes *.elm
