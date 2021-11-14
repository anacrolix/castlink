JS_OUTPUT = ../docs/elm.js

.PHONY: $(JS_OUTPUT)
$(JS_OUTPUT): *.elm
	elm make CastLink.elm --output $@

format:
	elm-format --yes *.elm
