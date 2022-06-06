mkdir -p dist
echo "#! /usr/bin/env node\n" > dist/make_cuts
imbac -p make_cuts.imba >> dist/make_cuts
cp main.lua dist/
